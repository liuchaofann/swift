//===--- AccessedStorageAnalysis.cpp  - Accessed Storage Analysis ---------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "sil-sea"

#include "swift/SILOptimizer/Analysis/AccessedStorageAnalysis.h"
#include "swift/SILOptimizer/Analysis/BasicCalleeAnalysis.h"
#include "swift/SILOptimizer/Analysis/FunctionOrder.h"
#include "swift/SILOptimizer/PassManager/PassManager.h"

using namespace swift;

static bool updateAccessKind(SILAccessKind &LHS, SILAccessKind RHS) {
  bool changed = false;
  // Assume we don't track Init/Deinit.
  if (LHS == SILAccessKind::Read && RHS == SILAccessKind::Modify) {
    LHS = RHS;
    changed = true;
  }
  return changed;
}

static bool updateOptionalAccessKind(Optional<SILAccessKind> &LHS,
                                     Optional<SILAccessKind> RHS) {
  if (RHS == None)
    return false;

  if (LHS == None) {
    LHS = RHS;
    return true;
  }
  return updateAccessKind(LHS.getValue(), RHS.getValue());
}

bool StorageAccessInfo::mergeFrom(const StorageAccessInfo &RHS) {
  assert(accessKind == SILAccessKind::Read
         || accessKind == SILAccessKind::Modify && "uninitialized info");
  bool changed = updateAccessKind(accessKind, RHS.accessKind);
  if (noNestedConflict && !RHS.noNestedConflict) {
    noNestedConflict = false;
    changed = true;
  }
  return changed;
}

bool FunctionAccessedStorage::summarizeFunction(SILFunction *F) {
  assert(storageAccessMap.empty() && "expected uninitialized results.");

  if (F->isDefinition())
    return false;

  // If the function definition is unavailable, set unidentifiedAccess to a
  // conservative value, since analyzeInstruction will never be called.
  //
  // If FunctionSideEffects can be summarized, use that information.
  FunctionSideEffects functionSideEffects;
  if (!functionSideEffects.summarizeFunction(F)) {
    setWorstEffects();
    // May as well consider this a successful summary since there are no
    // instructions to visit anyway.
    return true;
  }
  bool mayRead = functionSideEffects.getGlobalEffects().mayRead();
  bool mayWrite = functionSideEffects.getGlobalEffects().mayWrite();
  for (auto &paramEffects : functionSideEffects.getParameterEffects()) {
    mayRead |= paramEffects.mayRead();
    mayWrite |= paramEffects.mayWrite();
  }
  if (mayWrite)
    unidentifiedAccess = SILAccessKind::Modify;
  else if (mayRead)
    unidentifiedAccess = SILAccessKind::Read;

  // If function side effects is "readnone" then this result will have an empty
  // storageAccessMap and unidentifiedAccess == None.
  return true;
}

bool FunctionAccessedStorage::updateUnidentifiedAccess(
    SILAccessKind accessKind) {
  if (unidentifiedAccess == None) {
    unidentifiedAccess = accessKind;
    return true;
  }
  return updateAccessKind(unidentifiedAccess.getValue(), accessKind);
}

// Merge the given FunctionAccessedStorage in `other` into this
// FunctionAccessedStorage. Use the given `transformStorage` to map `other`
// AccessedStorage into this context. If `other` is from a callee, argument
// substitution will be performed if possible. However, there's no guarantee
// that the merged access values will belong to this function.
//
// Note that we may have `this` == `other` for self-recursion. We still need to
// propagate and merge in that case in case arguments are recursively dependent.
bool FunctionAccessedStorage::mergeAccesses(
    const FunctionAccessedStorage &other,
    std::function<AccessedStorage(const AccessedStorage &)> transformStorage) {

  // Insertion in DenseMap invalidates the iterator in the rare case of
  // self-recursion (`this` == `other`) that passes accessed storage though an
  // argument. Rather than complicate the code, make a temporary copy of the
  // AccessedStorage.
  SmallVector<std::pair<AccessedStorage, StorageAccessInfo>, 8> otherAccesses;
  otherAccesses.reserve(other.storageAccessMap.size());
  otherAccesses.append(other.storageAccessMap.begin(),
                       other.storageAccessMap.end());

  bool changed = false;
  for (auto &accessEntry : otherAccesses) {
    const AccessedStorage &storage = transformStorage(accessEntry.first);
    // transformStorage() returns invalid storage object for local storage
    // that should not be merged with the caller.
    if (!storage)
      continue;

    if (storage.getKind() == AccessedStorage::Unidentified) {
      changed |= updateUnidentifiedAccess(accessEntry.second.accessKind);
      continue;
    }
    // Attempt to add identified AccessedStorage to this map.
    auto result = storageAccessMap.try_emplace(storage, accessEntry.second);
    if (result.second) {
      // A new AccessedStorage key was added to this map.
      changed = true;
      continue;
    }
    // Merge StorageAccessInfo into already-mapped AccessedStorage.
    changed |= result.first->second.mergeFrom(accessEntry.second);
  }
  if (other.unidentifiedAccess != None)
    changed |= updateUnidentifiedAccess(other.unidentifiedAccess.getValue());

  return changed;
}

bool FunctionAccessedStorage::mergeFrom(const FunctionAccessedStorage &other) {
  // Merge accesses from other. Both `this` and `other` are either from the same
  // function or are both callees of the same call site, so their parameters
  // indices coincide. transformStorage is the identity function.
  return mergeAccesses(other, [](const AccessedStorage &s) { return s; });
}

/// Returns the argument of the full apply or partial apply corresponding to the
/// callee's parameter index, or returns an invalid SILValue if the applied
/// closure cannot be found. This walks up the apply chain starting at the given
/// `fullApply` to find the applied argument.
static SILValue getCallerArg(FullApplySite fullApply, unsigned paramIndex) {
  if (paramIndex < fullApply.getNumArguments())
    return fullApply.getArgument(paramIndex);

  SILValue callee = fullApply.getCalleeOrigin();
  auto *PAI = dyn_cast<PartialApplyInst>(callee);
  if (!PAI)
    return SILValue();

  unsigned appliedIndex =
    paramIndex - ApplySite(PAI).getCalleeArgIndexOfFirstAppliedArg();
  if (appliedIndex < PAI->getNumArguments())
    return PAI->getArgument(appliedIndex);

  // This must be a chain of partial_applies. We don't expect this in practice,
  // so handle it conservatively.
  return SILValue();
}

/// Transform AccessedStorage from a callee into the caller context. If this is
/// uniquely identified local storage, then return an invalid storage object.
static AccessedStorage transformCalleeStorage(const AccessedStorage &storage,
                                              FullApplySite fullApply) {
  switch (storage.getKind()) {
  case AccessedStorage::Box:
  case AccessedStorage::Stack:
    // Do not merge local storage.
    return AccessedStorage();
  case AccessedStorage::Global:
    // Global accesses is universal.
    return storage;
  case AccessedStorage::Class: {
    // If the object's value is an argument, translate it into a value on the
    // caller side.
    SILValue obj = storage.getObjectProjection().getObject();
    if (auto *arg = dyn_cast<SILFunctionArgument>(obj)) {
      SILValue argVal = getCallerArg(fullApply, arg->getIndex());
      if (argVal)
        return AccessedStorage(argVal,
                               storage.getObjectProjection().getProjection());
    }
    // Otherwise, continue to reference the value in the callee because we don't
    // have any better placeholder for a callee-defined object.
    return storage;
  }
  case AccessedStorage::Argument: {
    // Transitively search for the storage base in the caller.
    SILValue argVal = getCallerArg(fullApply, storage.getParamIndex());
    if (argVal)
      return findAccessedStorageOrigin(argVal);

    // If the argument can't be transformed, demote it to an unidentified
    // access.
    return AccessedStorage(storage.getValue(), AccessedStorage::Unidentified);
  }
  case AccessedStorage::Nested:
    llvm_unreachable("Unexpected nested access");
  case AccessedStorage::Unidentified:
    // For unidentified storage, continue to reference the value in the callee
    // because we don't have any better placeholder for a callee-defined object.
    return storage;
  }
}

bool FunctionAccessedStorage::mergeFromApply(
    const FunctionAccessedStorage &calleeAccess, FullApplySite fullApply) {
  // Merge accesses from calleeAccess. Transform any Argument type
  // AccessedStorage into the caller context to be added to `this` storage map.
  return mergeAccesses(calleeAccess, [&fullApply](const AccessedStorage &s) {
    return transformCalleeStorage(s, fullApply);
  });
}

template <typename B>
void FunctionAccessedStorage::visitBeginAccess(B *beginAccess) {
  if (beginAccess->getEnforcement() != SILAccessEnforcement::Dynamic)
    return;

  const AccessedStorage &storage =
      findAccessedStorageOrigin(beginAccess->getSource());

  if (storage.getKind() == AccessedStorage::Unidentified) {
    updateOptionalAccessKind(unidentifiedAccess, beginAccess->getAccessKind());
    return;
  }
  StorageAccessInfo accessInfo(beginAccess);
  auto result = storageAccessMap.try_emplace(storage, accessInfo);
  if (!result.second)
    result.first->second.mergeFrom(accessInfo);
}

void FunctionAccessedStorage::analyzeInstruction(SILInstruction *I) {
  if (auto *BAI = dyn_cast<BeginAccessInst>(I))
    visitBeginAccess(BAI);
  else if (auto *BUAI = dyn_cast<BeginUnpairedAccessInst>(I))
    visitBeginAccess(BUAI);
}

bool FunctionAccessedStorage::mayConflictWith(
    SILAccessKind otherAccessKind, const AccessedStorage &otherStorage) {
  if (unidentifiedAccess != None
      && accessKindMayConflict(otherAccessKind,
                               unidentifiedAccess.getValue())) {
    return true;
  }
  for (auto &accessEntry : storageAccessMap) {

    const AccessedStorage &storage = accessEntry.first;
    assert(storage && "FunctionAccessedStorage mapped invalid storage.");

    StorageAccessInfo accessInfo = accessEntry.second;
    if (!accessKindMayConflict(otherAccessKind, accessInfo.accessKind))
      continue;

    if (!otherStorage.isDistinctFrom(storage))
      return true;
  }
  return false;
}

void FunctionAccessedStorage::print(raw_ostream &os) const {
  for (auto &accessEntry : storageAccessMap) {
    const AccessedStorage &storage = accessEntry.first;
    const StorageAccessInfo &info = accessEntry.second;
    os << "  [" << getSILAccessKindName(info.accessKind) << "] ";
    if (info.noNestedConflict)
      os << "[no_nested_conflict] ";
    storage.print(os);
  }
  if (unidentifiedAccess != None) {
    os << "  unidentified accesses: "
       << getSILAccessKindName(unidentifiedAccess.getValue()) << "\n";
  }
}

void FunctionAccessedStorage::dump() const { print(llvm::errs()); }

SILAnalysis *swift::createAccessedStorageAnalysis(SILModule *) {
  return new AccessedStorageAnalysis();
}
