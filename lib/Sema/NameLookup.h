//===--- NameLookup.h - Swift Name Lookup Routines --------------*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file defines interfaces for performing name lookup.
//
//===----------------------------------------------------------------------===//

#ifndef SEMA_NAME_LOOKUP_H
#define SEMA_NAME_LOOKUP_H

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "swift/AST/Identifier.h"

namespace swift {
  class ASTContext;
  class Expr;
  class SourceLoc;
  class ValueDecl;
  class Type;
  class TypeDecl;
  class Module;
  class TupleType;

/// MemberLookupResult - One result of member name lookup.
struct MemberLookupResult {
  /// D - The decl found or tuple element referenced.
  union {
    ValueDecl *D;
    unsigned TupleFieldNo;
  };

  /// Kind - The kind of reference.
  enum KindTy {
    /// MemberProperty - "a.x" refers to an "x" which is an instance property
    /// of "a".
    MemberProperty,

    /// MemberFunction - "a.x" refers to an "x" which is an instance function
    /// of "a".  "A.x" refers to a curried function such that "A.x(a)" is
    /// equivalent to "x.a" if "A" is the metatype of the type of "a".
    MemberFunction,

    /// MetatypeMember - "A.x" refers to an "x" which is a member of the
    /// metatype "A". "a.x" is equivalent to "A.x", where "A' si the the
    /// metatype of the type of "a"; the base is evaluated and ignored.
    MetatypeMember,

    /// TupleElement - "a.x" is a direct reference to a field of a tuple.
    TupleElement,
  } Kind;
  
  static MemberLookupResult getMemberProperty(ValueDecl *D) {
    MemberLookupResult R;
    R.D = D;
    R.Kind = MemberProperty;
    return R;
  }
  static MemberLookupResult getMemberFunction(ValueDecl *D) {
    MemberLookupResult R;
    R.D = D;
    R.Kind = MemberFunction;
    return R;
  }
  static MemberLookupResult getMetatypeMember(ValueDecl *D) {
    MemberLookupResult R;
    R.D = D;
    R.Kind = MetatypeMember;
    return R;
  }
  static MemberLookupResult getTupleElement(unsigned Elt) {
    MemberLookupResult R;
    R.TupleFieldNo = Elt;
    R.Kind = TupleElement;
    return R;
  }
};
  
/// MemberLookup - This class implements and represents the result of performing
/// "dot" style member lookup and represents the result set.
class MemberLookup {
  MemberLookup(const MemberLookup&) = delete;
  void operator=(const MemberLookup&) = delete;
public:
  /// MemberLookup ctor - Lookup a member 'Name' in 'BaseTy' within the context
  /// of a given module 'M'.  This operation corresponds to a standard "dot" 
  /// lookup operation like "a.b" where 'this' is the type of 'a'.  This
  /// operation is only valid after name binding.
  MemberLookup(Type BaseTy, Identifier Name, Module &M);

  /// Results - The constructor fills this vector in with all of the results.
  /// If name lookup failed, this is empty.
  llvm::SmallVector<MemberLookupResult, 4> Results;
  
  /// isSuccess - Return true if anything was found by the name lookup.
  bool isSuccess() const { return !Results.empty(); }
  
  /// createResultAST - Build an AST to represent this lookup, with the
  /// specified base expression.
  Expr *createResultAST(Expr *Base, SourceLoc DotLoc, SourceLoc NameLoc,
                        ASTContext &Context);
  
private:
  Identifier MemberName;
  typedef llvm::SmallPtrSet<TypeDecl *, 8> VisitedSet;
  void doIt(Type BaseTy, Module &M, VisitedSet &Visited);
};

} // end namespace swift

#endif
