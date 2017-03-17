// RUN: %target-swift-frontend -enable-sil-opaque-values -emit-sorted-sil -Xllvm -new-mangling-for-tests -Xllvm -sil-full-demangle -emit-silgen %s | %FileCheck %s

// UNSUPPORTED: resilient_stdlib

struct TrivialStruct {
  var x: Int
}

protocol Foo {
  func foo()
}

protocol P {
  var x : Int { get }
}

protocol P2 : P {}

extension TrivialStruct : P2 {}

struct Box<T> {
  let t: T
}

protocol EmptyP {}

struct AddressOnlyStruct : EmptyP {}

struct AnyStruct {
  let a: Any
}

func s010_hasVarArg(_ args: Any...) {}

// Tests Address only enums's construction
// CHECK-LABEL: sil shared [transparent] @_T020opaque_values_silgen15AddressOnlyEnumO4mereAcA6EmptyP_pcACmF : $@convention(method) (@in EmptyP, @thin AddressOnlyEnum.Type) -> @out AddressOnlyEnum {
// CHECK: bb0([[ARG0:%.*]] : $EmptyP, [[ARG1:%.*]] : $@thin AddressOnlyEnum.Type):
// CHECK:   [[RETVAL:%.*]] = enum $AddressOnlyEnum, #AddressOnlyEnum.mere!enumelt.1, [[ARG0]] : $EmptyP
// CHECK:   return [[RETVAL]] : $AddressOnlyEnum
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen15AddressOnlyEnumO4mereAcA6EmptyP_pcACmF'
// CHECK-LABEL: sil shared [transparent] [thunk] @_T020opaque_values_silgen15AddressOnlyEnumO4mereAcA6EmptyP_pcACmFTc : $@convention(thin) (@thin AddressOnlyEnum.Type) -> @owned @callee_owned (@in EmptyP) -> @out AddressOnlyEnum {
// CHECK: bb0([[ARG:%.*]] : $@thin AddressOnlyEnum.Type):
// CHECK:   [[RETVAL:%.*]] = partial_apply {{.*}}([[ARG]]) : $@convention(method) (@in EmptyP, @thin AddressOnlyEnum.Type) -> @out AddressOnlyEnum
// CHECK:   return [[RETVAL]] : $@callee_owned (@in EmptyP) -> @out AddressOnlyEnum
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen15AddressOnlyEnumO4mereAcA6EmptyP_pcACmFTc'
enum AddressOnlyEnum {
  case nought
  case mere(EmptyP)
  case phantom(AddressOnlyStruct)
}

// part of s280_convExistTrivial: conversion between existential types - reabstraction thunk
// ---
// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_T020opaque_values_silgen1P_pAA13TrivialStructVIxid_AA2P2_pAaE_pIxir_TR : $@convention(thin) (@in P2, @owned @callee_owned (@in P) -> TrivialStruct) -> @out P2 {
// CHECK: bb0([[ARG0:%.*]] : $P2, [[ARG1:%.*]] : $@callee_owned (@in P) -> TrivialStruct):
// CHECK:   [[OPENED_ARG:%.*]] = open_existential_opaque [[ARG0]] : $P2 to $@opened({{.*}}) P2
// CHECK:   [[INIT_P:%.*]] = init_existential_opaque [[OPENED_ARG]] : $@opened({{.*}}) P2, $@opened({{.*}}) P2, $P
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[INIT_P]]
// CHECK:   [[APPLY_P:%.*]] = apply [[ARG1]]([[BORROWED_ARG]]) : $@callee_owned (@in P) -> TrivialStruct
// CHECK:   [[RETVAL:%.*]] = init_existential_opaque [[APPLY_P]] : $TrivialStruct, $TrivialStruct, $P2
// CHECK:   end_borrow [[BORROWED_ARG]] from [[INIT_P]] : $P, $P
// CHECK:   destroy_value [[OPENED_ARG]]
// CHECK:   deinit_existential_opaque [[ARG0]]
// CHECK:   return [[RETVAL]] : $P2
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen1P_pAA13TrivialStructVIxid_AA2P2_pAaE_pIxir_TR'

// part of s290_convOptExistTriv: conversion between existential types - reabstraction thunk - optionals case
// ---
// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_T020opaque_values_silgen1P_pSgAA13TrivialStructVIxid_AESgAA2P2_pIxyr_TR : $@convention(thin) (Optional<TrivialStruct>, @owned @callee_owned (@in Optional<P>) -> TrivialStruct) -> @out P2 {
// CHECK: bb0([[ARG0:%.*]] : $Optional<TrivialStruct>, [[ARG1:%.*]] : $@callee_owned (@in Optional<P>) -> TrivialStruct):
// CHECK:   switch_enum [[ARG0]] : $Optional<TrivialStruct>, case #Optional.some!enumelt.1: bb2, case #Optional.none!enumelt: bb1
// CHECK: bb1:
// CHECK:   [[ONONE:%.*]] = enum $Optional<P>, #Optional.none!enumelt
// CHECK:   br bb3([[ONONE]] : $Optional<P>)
// CHECK: bb2([[OSOME:%.*]] : $TrivialStruct):
// CHECK:   [[INIT_S:%.*]] = init_existential_opaque [[OSOME]] : $TrivialStruct, $TrivialStruct, $P
// CHECK:   [[ENUM_S:%.*]] = enum $Optional<P>, #Optional.some!enumelt.1, [[INIT_S]] : $P
// CHECK:   br bb3([[ENUM_S]] : $Optional<P>)
// CHECK: bb3([[OPT_S:%.*]] : $Optional<P>):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[OPT_S]]
// CHECK:   [[APPLY_P:%.*]] = apply [[ARG1]]([[BORROWED_ARG]]) : $@callee_owned (@in Optional<P>) -> TrivialStruct
// CHECK:   [[RETVAL:%.*]] = init_existential_opaque [[APPLY_P]] : $TrivialStruct, $TrivialStruct, $P2
// CHECK:   end_borrow [[BORROWED_ARG]] from [[OPT_S]] : $Optional<P>, $Optional<P>
// CHECK:   destroy_value [[OPT_S]]
// CHECK:   return [[RETVAL]] : $P2
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen1P_pSgAA13TrivialStructVIxid_AESgAA2P2_pIxyr_TR'

// Test that we still use addresses when dealing with array initialization
// ---
// CHECK-LABEL: sil @_T020opaque_values_silgen21s020_______callVarArgyyF : $@convention(thin) () -> () {
// CHECK: %[[APY:.*]] = apply %{{.*}}<Any>(%{{.*}}) : $@convention(thin) <τ_0_0> (Builtin.Word) -> (@owned Array<τ_0_0>, Builtin.RawPointer)
// CHECK: %[[BRW:.*]] = begin_borrow %[[APY]]
// CHECK: %[[TPL:.*]] = tuple_extract %[[BRW]] : $(Array<Any>, Builtin.RawPointer), 1
// CHECK: end_borrow %[[BRW]] from %[[APY]] : $(Array<Any>, Builtin.RawPointer), $(Array<Any>, Builtin.RawPointer)
// CHECK: destroy_value %[[APY]]
// CHECK: %[[PTR:.*]] = pointer_to_address %[[TPL]] : $Builtin.RawPointer to [strict] $*Any
// CHECK: init_existential_addr %[[PTR]] : $*Any, $Int
// CHECK: return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s020_______callVarArgyyF'
public func s020_______callVarArg() {
  s010_hasVarArg(3)
}

// Test emitSemanticStore.
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s030______assigninoutyxz_xtlF : $@convention(thin) <T> (@inout T, @in T) -> () {
// CHECK: bb0([[ARG0:%.*]] : $*T, [[ARG1:%.*]] : $T):
// CHECK:   [[BORROWED_ARG1:%.*]] = begin_borrow [[ARG1]]
// CHECK:   [[CPY:%.*]] = copy_value [[BORROWED_ARG1]] : $T
// CHECK:   assign [[CPY]] to [[ARG0]] : $*T
// CHECK:   end_borrow [[BORROWED_ARG1]] from [[ARG1]]
// CHECK:   destroy_value [[ARG1]] : $T
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s030______assigninoutyxz_xtlF'
func s030______assigninout<T>(_ a: inout T, _ b: T) {
  a = b
}

// Test that we no longer use copy_addr or tuple_element_addr when copy by value is possible
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s040___tupleReturnIntS2i_xtlF : $@convention(thin) <T> (Int, @in T) -> Int {
// CHECK: bb0([[ARG0:%.*]] : $Int, [[ARG1:%.*]] : $T):
// CHECK:   [[TPL:%.*]] = tuple ([[ARG0]] : $Int, [[ARG1]] : $T)
// CHECK:   [[BORROWED_ARG1:%.*]] = begin_borrow [[TPL]] : $(Int, T)
// CHECK:   [[CPY:%.*]] = copy_value [[BORROWED_ARG1]] : $(Int, T)
// CHECK:   [[BORROWED_CPY:%.*]] = begin_borrow [[CPY]]
// CHECK:   [[INT:%.*]] = tuple_extract [[BORROWED_CPY]] : $(Int, T), 0
// CHECK:   [[GEN:%.*]] = tuple_extract [[BORROWED_CPY]] : $(Int, T), 1
// CHECK:   [[COPY_GEN:%.*]] = copy_value [[GEN]]
// CHECK:   destroy_value [[COPY_GEN]]
// CHECK:   end_borrow [[BORROWED_CPY]] from [[CPY]]
// CHECK:   destroy_value [[CPY]]
// CHECK:   end_borrow [[BORROWED_ARG1]] from [[TPL]] : $(Int, T), $(Int, T)
// CHECK:   destroy_value [[TPL]] : $(Int, T)
// CHECK:   return [[INT]]
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s040___tupleReturnIntS2i_xtlF'
func s040___tupleReturnInt<T>(_ x: (Int, T)) -> Int {
  let y = x.0
  return y
}

// Test returning an opaque tuple of tuples.
// ---
// CHECK-LABEL: sil hidden [noinline] @_T020opaque_values_silgen21s050______multiResultx_x_xttxlF : $@convention(thin) <T> (@in T) -> (@out T, @out T, @out T) {
// CHECK: bb0(%0 : $T):
// CHECK: %[[CP1:.*]] = copy_value %{{.*}} : $T
// CHECK: %[[CP2:.*]] = copy_value %{{.*}} : $T
// CHECK: %[[CP3:.*]] = copy_value %{{.*}} : $T
// CHECK: destroy_value %0 : $T
// CHECK: %[[TPL:.*]] = tuple (%[[CP1]] : $T, %[[CP2]] : $T, %[[CP3]] : $T)
// CHECK: return %[[TPL]] : $(T, T, T)
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s050______multiResultx_x_xttxlF'
@inline(never)
func s050______multiResult<T>(_ t: T) -> (T, (T, T)) {
  return (t, (t, t))
}

// Test returning an opaque tuple of tuples as a concrete tuple.
// ---
// CHECK-LABEL: sil @_T020opaque_values_silgen21s060__callMultiResultSi_Si_SittSi1i_tF : $@convention(thin) (Int) -> (Int, Int, Int) {
// CHECK: bb0(%0 : $Int):
// CHECK: %[[FN:.*]] = function_ref @_T020opaque_values_silgen21s050______multiResultx_x_xttxlF : $@convention(thin) <τ_0_0> (@in τ_0_0) -> (@out τ_0_0, @out τ_0_0, @out τ_0_0)
// CHECK: %[[TPL:.*]] = apply %[[FN]]<Int>(%0) : $@convention(thin) <τ_0_0> (@in τ_0_0) -> (@out τ_0_0, @out τ_0_0, @out τ_0_0)
// CHECK: %[[I1:.*]] = tuple_extract %[[TPL]] : $(Int, Int, Int), 0
// CHECK: %[[I2:.*]] = tuple_extract %[[TPL]] : $(Int, Int, Int), 1
// CHECK: %[[I3:.*]] = tuple_extract %[[TPL]] : $(Int, Int, Int), 2
// CHECK: %[[R:.*]] = tuple (%[[I1]] : $Int, %[[I2]] : $Int, %[[I3]] : $Int)
// CHECK: return %[[R]] : $(Int, Int, Int)
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s060__callMultiResultSi_Si_SittSi1i_tF'
public func s060__callMultiResult(i: Int) -> (Int, (Int, Int)) {
  return s050______multiResult(i)
}

// SILGen, prepareArchetypeCallee. Materialize a
// non-class-constrainted self from a class-constrained archetype.
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s070__materializeSelfyx1t_ts9AnyObjectRzAA3FooRzlF : $@convention(thin) <T where T : AnyObject, T : Foo> (@owned T) -> () {
// CHECK: bb0([[ARG:%.*]] : $T):
// CHECK: [[WITNESS_METHOD:%.*]] = witness_method $T, #Foo.foo!1 : <Self where Self : Foo> (Self) -> () -> () : $@convention(witness_method) <τ_0_0 where τ_0_0 : Foo> (@in_guaranteed τ_0_0) -> ()
// CHECK: [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK: apply [[WITNESS_METHOD]]<T>([[BORROWED_ARG]]) : $@convention(witness_method) <τ_0_0 where τ_0_0 : Foo> (@in_guaranteed τ_0_0) -> ()
// CHECK: end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK: destroy_value [[ARG]] : $T
// CHECK: return %{{[0-9]+}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s070__materializeSelfyx1t_ts9AnyObjectRzAA3FooRzlF'
func s070__materializeSelf<T: Foo>(t: T) where T: AnyObject {
  t.foo()
}

// Test open existential with opaque values
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s080______________barSiAA1P_p1p_tF : $@convention(thin) (@in P) -> Int {
// CHECK: bb0([[ARG:%.*]] : $P):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[OPENED_ARG:%.*]] = open_existential_opaque [[BORROWED_ARG]] : $P to $@opened
// CHECK:   [[WITNESS_FUNC:%.*]] = witness_method $@opened
// CHECK:   [[RESULT:%.*]] = apply [[WITNESS_FUNC]]<{{.*}}>([[OPENED_ARG]]) : $@convention(witness_method) <τ_0_0 where τ_0_0 : P> (@in_guaranteed τ_0_0) -> Int
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $P
// CHECK:   return [[RESULT]] : $Int
func s080______________bar(p: P) -> Int {
  return p.x
}

// Test OpaqueTypeLowering copyValue and destroyValue.
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s090___________callerxxlF : $@convention(thin) <T> (@in T) -> @out T {
// CHECK: bb0([[ARG:%.*]] : $T):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY:%.*]] = copy_value [[BORROWED_ARG]] : $T
// CHECK:   [[RESULT:%.*]] = apply {{%.*}}<T>([[COPY]]) : $@convention(thin) <τ_0_0> (@in τ_0_0) -> @out τ_0_0
// CHECK:   end_borrow [[BORROWED_ARG:%.*]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $T
// CHECK:   return %{{.*}} : $T
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s090___________callerxxlF'
func s090___________caller<T>(_ t: T) -> T {
  return s090___________caller(t)
}

// Test a simple opaque parameter and return value.
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s100_________identityxx1t_tlF : $@convention(thin) <T> (@in T) -> @out T {
// CHECK: bb0([[ARG:%.*]] : $T):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]] : $T
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $T
// CHECK:   return [[COPY_ARG]] : $T
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s100_________identityxx1t_tlF'
func s100_________identity<T>(t: T) -> T {
  return t
}

// Test a guaranteed opaque parameter.
// ---
// CHECK-LABEL: sil hidden [transparent] [thunk] @_T020opaque_values_silgen21s110___GuaranteedSelfVAA3FooA2aDP3fooyyFTW : $@convention(witness_method) (@in_guaranteed s110___GuaranteedSelf) -> () {
// CHECK: bb0(%0 : $s110___GuaranteedSelf):
// CHECK:   %[[F:.*]] = function_ref @_T020opaque_values_silgen21s110___GuaranteedSelfV3fooyyF : $@convention(method) (s110___GuaranteedSelf) -> ()
// CHECK:   apply %[[F]](%0) : $@convention(method) (s110___GuaranteedSelf) -> ()
// CHECK:   return
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s110___GuaranteedSelfVAA3FooA2aDP3fooyyFTW'
struct s110___GuaranteedSelf : Foo {
  func foo() {}
}

// Tests a corner case wherein we used to do a temporary and return a pointer to T instead of T
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s120______returnValuexxlF : $@convention(thin) <T> (@in T) -> @out T {
// CHECK: bb0([[ARG:%.*]] : $T):
// CHECK:   [[BORROWED_ARG1:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG1:%.*]] = copy_value [[BORROWED_ARG1]] : $T
// CHECK:   end_borrow [[BORROWED_ARG1]] from [[ARG]]
// CHECK:   [[BORROWED_ARG2:%.*]] = begin_borrow [[COPY_ARG1]]
// CHECK:   [[COPY_ARG2:%.*]] = copy_value [[BORROWED_ARG2]] : $T
// CHECK:   end_borrow [[BORROWED_ARG2]] from [[COPY_ARG1]]
// CHECK:   return [[COPY_ARG2]] : $T
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s120______returnValuexxlF'
func s120______returnValue<T>(_ x: T) -> T {
  let y = x
  return y
}

// Tests Optional initialization by value
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s130_____________wrapxSgxlF : $@convention(thin) <T> (@in T) -> @out Optional<T> {
// CHECK: bb0([[ARG:%.*]] : $T):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]] : $T
// CHECK:   [[OPTIONAL_ARG:%.*]] = enum $Optional<T>, #Optional.some!enumelt.1, [[COPY_ARG]] : $T
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $T
// CHECK:   return [[OPTIONAL_ARG]] : $Optional<T>
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s130_____________wrapxSgxlF'
func s130_____________wrap<T>(_ x: T) -> T? {
  return x
}

// Tests For-each statements
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s140______forEachStmtyyF : $@convention(thin) () -> () {
// CHECK: bb0:
// CHECK:   [[PROJ_BOX_ARG:%.*]] = project_box %{{.*}} : ${ var IndexingIterator<CountableRange<Int>> }
// CHECK:   [[APPLY_ARG1:%.*]] = apply
// CHECK-NOT: alloc_stack $Int
// CHECK-NOT: store [[APPLY_ARG1]] to [trivial]
// CHECK-NOT: alloc_stack $CountableRange<Int>
// CHECK-NOT: dealloc_stack
// CHECK:   [[APPLY_ARG2:%.*]] = apply %{{.*}}<CountableRange<Int>>
// CHECK:   store [[APPLY_ARG2]] to [trivial] [[PROJ_BOX_ARG]]
// CHECK:   br bb1
// CHECK: bb1:
// CHECK-NOT: alloc_stack $Optional<Int>
// CHECK:   [[APPLY_ARG3:%.*]] = apply %{{.*}}<CountableRange<Int>>
// CHECK-NOT: dealloc_stack
// CHECK:   switch_enum [[APPLY_ARG3]]
// CHECK: bb2:
// CHECK:   br bb3
// CHECK: bb3:
// CHECK:   return %{{.*}} : $()
// CHECK: bb4([[ENUM_ARG:%.*]] : $Int):
// CHECK-NOT:   unchecked_enum_data
// CHECK:   br bb1
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s140______forEachStmtyyF'
func s140______forEachStmt() {
  for _ in 1..<42 {
  }
}

func s150___________anyArg(_: Any) {}

// Tests init of opaque existentials
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s160_______callAnyArgyyF : $@convention(thin) () -> () {
// CHECK: bb0:
// CHECK:   [[INT_TYPE:%.*]] = metatype $@thin Int.Type
// CHECK:   [[INT_LIT:%.*]] = integer_literal $Builtin.Int2048, 42
// CHECK:   [[INT_ARG:%.*]] = apply %{{.*}}([[INT_LIT]], [[INT_TYPE]]) : $@convention(method) (Builtin.Int2048, @thin Int.Type) -> Int
// CHECK:   [[INIT_OPAQUE:%.*]] = init_existential_opaque [[INT_ARG]] : $Int, $Int, $Any
// CHECK:   apply %{{.*}}([[INIT_OPAQUE]]) : $@convention(thin) (@in Any) -> ()
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s160_______callAnyArgyyF'
func s160_______callAnyArg() {
  s150___________anyArg(42)
}

// Tests unconditional_checked_cast for opaque values
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s170____force_convertxylF : $@convention(thin) <T> () -> @out T {
// CHECK: bb0:
// CHECK-NOT: alloc_stack
// CHECK:   [[INT_TYPE:%.*]] = metatype $@thin Int.Type
// CHECK:   [[INT_LIT:%.*]] = integer_literal $Builtin.Int2048, 42
// CHECK:   [[INT_ARG:%.*]] = apply %{{.*}}([[INT_LIT]], [[INT_TYPE]]) : $@convention(method) (Builtin.Int2048, @thin Int.Type) -> Int
// CHECK:   [[INT_CAST:%.*]] = unconditional_checked_cast_value take_always [[INT_ARG]] : $Int to $T
// CHECK:   [[CAST_BORROW:%.*]] = begin_borrow [[INT_CAST]] : $T
// CHECK:   [[RETURN_VAL:%.*]] = copy_value [[CAST_BORROW]] : $T
// CHECK:   end_borrow [[CAST_BORROW]] from [[INT_CAST]] : $T, $T
// CHECK:   destroy_value [[INT_CAST]] : $T
// CHECK:   return [[RETURN_VAL]] : $T
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s170____force_convertxylF'
func s170____force_convert<T>() -> T {
  let x : T = 42 as! T
  return x
}

// Tests supporting function for s190___return_foo_var - cast and return of protocol
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s180_______return_fooAA3Foo_pyF : $@convention(thin) () -> @out Foo {
// CHECK: bb0:
// CHECK:   [[INT_LIT:%.*]] = integer_literal $Builtin.Int2048, 42
// CHECK:   [[INT_ARG:%.*]] = apply %{{.*}}([[INT_LIT]], [[INT_TYPE]]) : $@convention(method) (Builtin.Int2048, @thin Int.Type) -> Int
// CHECK:   [[INT_CAST:%.*]] = unconditional_checked_cast_value take_always [[INT_ARG]] : $Int to $Foo
// CHECK:   return [[INT_CAST]] : $Foo
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s180_______return_fooAA3Foo_pyF'
func s180_______return_foo() -> Foo {
  return 42 as! Foo
}
var foo_var : Foo = s180_______return_foo()

// Tests return of global variables by doing a load of copy
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s190___return_foo_varAA3Foo_pyF : $@convention(thin) () -> @out Foo {
// CHECK: bb0:
// CHECK:   [[GLOBAL:%.*]] = global_addr {{.*}} : $*Foo
// CHECK:   [[LOAD_GLOBAL:%.*]] = load [copy] [[GLOBAL]] : $*Foo
// CHECK:   return [[LOAD_GLOBAL]] : $Foo
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s190___return_foo_varAA3Foo_pyF'
func s190___return_foo_var() -> Foo {
  return foo_var
}

// Tests deinit of opaque existentials
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s200______use_foo_varyyF : $@convention(thin) () -> () {
// CHECK: bb0:
// CHECK:   [[GLOBAL:%.*]] = global_addr {{.*}} : $*Foo
// CHECK:   [[LOAD_GLOBAL:%.*]] = load [copy] [[GLOBAL]] : $*Foo
// CHECK:   [[OPEN_VAR:%.*]] = open_existential_opaque [[LOAD_GLOBAL]] : $Foo
// CHECK:   [[WITNESS:%.*]] = witness_method $@opened
// CHECK:   apply [[WITNESS]]
// CHECK:   destroy_value [[OPEN_VAR]]
// CHECK:   deinit_existential_opaque [[LOAD_GLOBAL]] : $Foo
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s200______use_foo_varyyF'
func s200______use_foo_var() {
  foo_var.foo()
}

// Tests composition erasure of opaque existentials + copy into of opaques
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s210______compErasures5Error_psAC_AA3FoopF : $@convention(thin) (@in Error & Foo) -> @owned Error {
// CHECK: bb0([[ARG:%.*]] : $Error & Foo):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[OPAQUE_ARG:%.*]] = open_existential_opaque [[BORROWED_ARG]] : $Error & Foo to $@opened({{.*}}) Error & Foo
// CHECK:   [[EXIST_BOX:%.*]] = alloc_existential_box $Error, $@opened({{.*}}) Error & Foo
// CHECK:   [[PROJ_BOX:%.*]] = project_existential_box $@opened({{.*}}) Error & Foo in [[EXIST_BOX]]
// CHECK:   [[COPY_OPAQUE:%.*]] = copy_value [[OPAQUE_ARG]] : $@opened({{.*}}) Error & Foo
// CHECK:   store [[COPY_OPAQUE]] to [init] [[PROJ_BOX]] : $*@opened({{.*}}) Error & Foo
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $Error & Foo
// CHECK:   return [[EXIST_BOX]] : $Error
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s210______compErasures5Error_psAC_AA3FoopF'
func s210______compErasure(_ x: Foo & Error) -> Error {
  return x
}

// Tests that existential boxes can contain opaque types
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s220_____openExistBoxSSs5Error_pF : $@convention(thin) (@owned Error) -> @owned String {
// CHECK: bb0([[ARG:%.*]] : $Error):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[OPAQUE_ARG:%.*]] = open_existential_box [[BORROWED_ARG]] : $Error to $*@opened({{.*}}) Error
// CHECK:   [[ALLOC_OPEN:%.*]] = alloc_stack $@opened({{.*}}) Error
// CHECK:   copy_addr [[OPAQUE_ARG]] to [initialization] [[ALLOC_OPEN]] : $*@opened({{.*}}) Error
// CHECK:   [[LOAD_ALLOC:%.*]] = load [take] [[ALLOC_OPEN]]
// CHECK:   destroy_value [[LOAD_ALLOC]]
// CHECK:   dealloc_stack [[ALLOC_OPEN]]
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   destroy_value [[ARG]] : $Error
// CHECK:   return {{.*}} : $String
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s220_____openExistBoxSSs5Error_pF'
func s220_____openExistBox(_ x: Error) -> String {
  return x._domain
}

// Tests conditional value casts and correspondingly generated reabstraction thunk
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s230______condFromAnyyypF : $@convention(thin) (@in Any) -> () {
// CHECK: bb0([[ARG:%.*]] : $Any):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY__ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   checked_cast_value_br [[COPY__ARG]] : $Any to $@callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int), bb2, bb1
// CHECK: bb2([[THUNK_PARAM:%.*]] : $@callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int)):
// CHECK:   [[THUNK_REF:%.*]] = function_ref @{{.*}} : $@convention(thin) (Int, Int, Int, Int, Int, @owned @callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int)) -> (Int, Int, Int, Int, Int)
// CHECK:   partial_apply [[THUNK_REF]]([[THUNK_PARAM]])
// CHECK: bb6:
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s230______condFromAnyyypF'
func s230______condFromAny(_ x: Any) {
  if let f = x as? (Int, (Int, (Int, Int)), Int) -> (Int, (Int, (Int, Int)), Int) {
    _ = f(24, (4,(2, 42)), 42)
  }
}

// Tests LValue of error types / existential boxes
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s240_____propOfLValueSSs5Error_pF : $@convention(thin) (@owned Error) -> @owned String {
// CHECK: bb0([[ARG:%.*]] : $Error):
// CHECK:   [[ALLOC_OF_BOX:%.*]] = alloc_box ${ var Error }
// CHECK:   [[PROJ_BOX:%.*]] = project_box [[ALLOC_OF_BOX]]
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   store [[COPY_ARG]] to [init] [[PROJ_BOX]]
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]]
// CHECK:   [[LOAD_BOX:%.*]] = load [copy] [[PROJ_BOX]]
// CHECK:   [[OPAQUE_ARG:%.*]] = open_existential_box [[LOAD_BOX]] : $Error to $*@opened({{.*}}) Error
// CHECK:   [[LOAD_OPAQUE:%.*]] = load [copy] [[OPAQUE_ARG]]
// CHECK:   [[ALLOC_OPEN:%.*]] = alloc_stack $@opened({{.*}}) Error
// CHECK:   store [[LOAD_OPAQUE]] to [init] [[ALLOC_OPEN]]
// CHECK:   [[RET_VAL:%.*]] = apply {{.*}}<@opened({{.*}}) Error>([[ALLOC_OPEN]])
// CHECK:   return [[RET_VAL]] : $String
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s240_____propOfLValueSSs5Error_pF'
func s240_____propOfLValue(_ x: Error) -> String {
  var x = x
  return x._domain
}

// Tests Implicit Value Construction under Opaque value mode
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s250_________testBoxTyyF : $@convention(thin) () -> () {
// CHECK: bb0:
// CHECK:   [[BOX_MTYPE:%.*]] = metatype $@thin Box<Int>.Type
// CHECK:   [[MTYPE:%.*]] = metatype $@thin Int.Type
// CHECK:   [[INTLIT:%.*]] = integer_literal $Builtin.Int2048, 42
// CHECK:   [[AINT:%.*]] = apply {{.*}}([[INTLIT]], [[MTYPE]]) : $@convention(method) (Builtin.Int2048, @thin Int.Type) -> Int
// CHECK:   apply {{.*}}<Int>([[AINT]], [[BOX_MTYPE]]) : $@convention(method) <τ_0_0> (@in τ_0_0, @thin Box<τ_0_0>.Type) -> @out Box<τ_0_0>
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s250_________testBoxTyyF'
func s250_________testBoxT() {
  let _ = Box(t: 42)
}

// Tests Address only enums
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s260_______AOnly_enumyAA17AddressOnlyStructVF : $@convention(thin) (AddressOnlyStruct) -> () {
// CHECK: bb0([[ARG:%.*]] : $AddressOnlyStruct):
// CHECK:   [[MTYPE1:%.*]] = metatype $@thin AddressOnlyEnum.Type
// CHECK:   [[APPLY1:%.*]] =  apply {{.*}}([[MTYPE1]]) : $@convention(thin) (@thin AddressOnlyEnum.Type) -> @owned @callee_owned (@in EmptyP) -> @out AddressOnlyEnum
// CHECK:   destroy_value [[APPLY1]]
// CHECK:   [[MTYPE2:%.*]] = metatype $@thin AddressOnlyEnum.Type
// CHECK:   [[ENUM1:%.*]] = enum $AddressOnlyEnum, #AddressOnlyEnum.nought!enumelt
// CHECK:   [[MTYPE3:%.*]] = metatype $@thin AddressOnlyEnum.Type
// CHECK:   [[INIT_OPAQUE:%.*]] = init_existential_opaque [[ARG]] : $AddressOnlyStruct, $AddressOnlyStruct, $EmptyP
// CHECK:   [[ENUM2:%.*]] = enum $AddressOnlyEnum, #AddressOnlyEnum.mere!enumelt.1, [[INIT_OPAQUE]] : $EmptyP
// CHECK:   destroy_value [[ENUM2]]
// CHECK:   [[MTYPE4:%.*]] = metatype $@thin AddressOnlyEnum.Type
// CHECK:   [[ENUM3:%.*]] = enum $AddressOnlyEnum, #AddressOnlyEnum.phantom!enumelt.1, [[ARG]] : $AddressOnlyStruct
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s260_______AOnly_enumyAA17AddressOnlyStructVF'
func s260_______AOnly_enum(_ s: AddressOnlyStruct) {
  _ = AddressOnlyEnum.mere

  _ = AddressOnlyEnum.nought

  _ = AddressOnlyEnum.mere(s)

  _ = AddressOnlyEnum.phantom(s)
}

// Tests InjectOptional for opaque value types + conversion of opaque structs
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s270_convOptAnyStructyAA0gH0VADSgcF : $@convention(thin) (@owned @callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct) -> () {
// CHECK: bb0([[ARG:%.*]] : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   [[PAPPLY:%.*]] = partial_apply %{{.*}}([[COPY_ARG]]) : $@convention(thin) (@in Optional<AnyStruct>, @owned @callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct) -> @out Optional<AnyStruct>
// CHECK:   destroy_value [[PAPPLY]] : $@callee_owned (@in Optional<AnyStruct>) -> @out Optional<AnyStruct>
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]] : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct, $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct
// CHECK:   [[BORROWED_ARG2:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG2:%.*]] = copy_value [[BORROWED_ARG2]]
// CHECK:   [[PAPPLY2:%.*]] = partial_apply %{{.*}}([[COPY_ARG2]]) : $@convention(thin) (@in Optional<AnyStruct>, @owned @callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct) -> @out Optional<AnyStruct>
// CHECK:   destroy_value [[PAPPLY2]] : $@callee_owned (@in Optional<AnyStruct>) -> @out Optional<AnyStruct>
// CHECK:   end_borrow [[BORROWED_ARG2]] from [[ARG]] : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct, $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct
// CHECK:   destroy_value [[ARG]] : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s270_convOptAnyStructyAA0gH0VADSgcF'
func s270_convOptAnyStruct(_ a1: @escaping (AnyStruct?) -> AnyStruct) {
  let _: (AnyStruct?) -> AnyStruct? = a1
  let _: (AnyStruct!) -> AnyStruct? = a1
}

// Tests conversion between existential types
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s280_convExistTrivialyAA0G6StructVAA1P_pcF : $@convention(thin) (@owned @callee_owned (@in P) -> TrivialStruct) -> () {
// CHECK: bb0([[ARG:%.*]] : $@callee_owned (@in P) -> TrivialStruct):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   [[PAPPLY:%.*]] = partial_apply %{{.*}}([[COPY_ARG]]) : $@convention(thin) (@in P2, @owned @callee_owned (@in P) -> TrivialStruct) -> @out P2
// CHECK:   destroy_value [[PAPPLY]] : $@callee_owned (@in P2) -> @out P2
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]] : $@callee_owned (@in P) -> TrivialStruct
// CHECK:   destroy_value [[ARG]]
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s280_convExistTrivialyAA0G6StructVAA1P_pcF'
func s280_convExistTrivial(_ s: @escaping (P) -> TrivialStruct) {
  let _: (P2) -> P2 = s
}

// Tests conversion between existential types - optionals case
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s290_convOptExistTrivyAA13TrivialStructVAA1P_pSgcF : $@convention(thin) (@owned @callee_owned (@in Optional<P>) -> TrivialStruct) -> () {
// CHECK: bb0([[ARG:%.*]] : $@callee_owned (@in Optional<P>) -> TrivialStruct):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
// CHECK:   [[COPY_ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   [[PAPPLY:%.*]] = partial_apply %{{.*}}([[COPY_ARG]]) : $@convention(thin) (Optional<TrivialStruct>, @owned @callee_owned (@in Optional<P>) -> TrivialStruct) -> @out P2
// CHECK:   destroy_value [[PAPPLY]] : $@callee_owned (Optional<TrivialStruct>) -> @out P2
// CHECK:   end_borrow [[BORROWED_ARG]] from [[ARG]] : $@callee_owned (@in Optional<P>) -> TrivialStruct, $@callee_owned (@in Optional<P>) -> TrivialStruct
// CHECK:   destroy_value [[ARG]]
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s290_convOptExistTrivyAA13TrivialStructVAA1P_pSgcF'
func s290_convOptExistTriv(_ s: @escaping (P?) -> TrivialStruct) {
  let _: (TrivialStruct?) -> P2 = s
}

// Tests conditional value casts and correspondingly generated reabstraction thunk, with <T> types
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen21s999_____condTFromAnyyyp_xtlF : $@convention(thin) <T> (@in Any, @in T) -> () {
// CHECK: bb0([[ARG0:%.*]] : $Any, [[ARG1:%.*]] : $T):
// CHECK:   [[BORROWED_ARG:%.*]] = begin_borrow [[ARG0]]
// CHECK:   [[COPY__ARG:%.*]] = copy_value [[BORROWED_ARG]]
// CHECK:   checked_cast_value_br [[COPY__ARG]] : $Any to $@callee_owned (@in (Int, T)) -> @out (Int, T), bb2, bb1
// CHECK: bb2([[THUNK_PARAM:%.*]] : $@callee_owned (@in (Int, T)) -> @out (Int, T)):
// CHECK:   [[THUNK_REF:%.*]] = function_ref @{{.*}} : $@convention(thin) <τ_0_0> (Int, @in τ_0_0, @owned @callee_owned (@in (Int, τ_0_0)) -> @out (Int, τ_0_0)) -> (Int, @out τ_0_0)
// CHECK:   partial_apply [[THUNK_REF]]<T>([[THUNK_PARAM]])
// CHECK: bb6:
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen21s999_____condTFromAnyyyp_xtlF'
func s999_____condTFromAny<T>(_ x: Any, _ y: T) {
  if let f = x as? (Int, T) -> (Int, T) {
    f(42, y)
  }
}

// s250_________testBoxT continued Test Implicit Value Construction under Opaque value mode
// ---
// CHECK-LABEL: sil hidden @_T020opaque_values_silgen3BoxVACyxGx1t_tcfC : $@convention(method) <T> (@in T, @thin Box<T>.Type) -> @out Box<T> {
// CHECK: bb0([[ARG0:%.*]] : $T, [[ARG1:%.*]] : $@thin Box<T>.Type):
// CHECK:   [[RETVAL:%.*]] = struct $Box<T> ([[ARG0]] : $T)
// CHECK:   return [[RETVAL]] : $Box<T>
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen3BoxVACyxGx1t_tcfC'

// s270_convOptAnyStruct continued Test: reabstraction thunk helper
// ---
// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_T020opaque_values_silgen9AnyStructVSgACIxir_A2DIxir_TR : $@convention(thin) (@in Optional<AnyStruct>, @owned @callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct) -> @out Optional<AnyStruct> {
// CHECK: bb0([[ARG0:%.*]] : $Optional<AnyStruct>, [[ARG1:%.*]] : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct):
// CHECK:   [[APPLYARG:%.*]] = apply [[ARG1]]([[ARG0]]) : $@callee_owned (@in Optional<AnyStruct>) -> @out AnyStruct
// CHECK:   [[RETVAL:%.*]] = enum $Optional<AnyStruct>, #Optional.some!enumelt.1, [[APPLYARG]] : $AnyStruct
// CHECK:   return [[RETVAL]] : $Optional<AnyStruct>
// CHECK-LABEL: } // end sil function '_T020opaque_values_silgen9AnyStructVSgACIxir_A2DIxir_TR'

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @{{.*}} : $@convention(thin) (Int, Int, Int, Int, Int, @owned @callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int)) -> (Int, Int, Int, Int, Int)
// CHECK: bb0([[ARG0:%.*]] : $Int, [[ARG1:%.*]] : $Int, [[ARG2:%.*]] : $Int, [[ARG3:%.*]] : $Int, [[ARG4:%.*]] : $Int, [[ARG5:%.*]] : $@callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int)):
// CHECK:   [[TUPLE_TO_APPLY0:%.*]] = tuple ([[ARG2]] : $Int, [[ARG3]] : $Int)
// CHECK:   [[TUPLE_TO_APPLY1:%.*]] = tuple ([[ARG1]] : $Int, [[TUPLE_TO_APPLY0]] : $(Int, Int))
// CHECK:   [[TUPLE_TO_APPLY2:%.*]] = tuple ([[ARG0]] : $Int, [[TUPLE_TO_APPLY1]] : $(Int, (Int, Int)), [[ARG4]] : $Int)
// CHECK:   [[TUPLE_APPLY:%.*]] = apply [[ARG5]]([[TUPLE_TO_APPLY2]]) : $@callee_owned (@in (Int, (Int, (Int, Int)), Int)) -> @out (Int, (Int, (Int, Int)), Int)
// CHECK:   [[RET_VAL0:%.*]] = tuple_extract [[TUPLE_APPLY]] : $(Int, (Int, (Int, Int)), Int), 0
// CHECK:   [[TUPLE_EXTRACT1:%.*]] = tuple_extract [[TUPLE_APPLY]] : $(Int, (Int, (Int, Int)), Int), 1
// CHECK:   [[RET_VAL1:%.*]] = tuple_extract [[TUPLE_EXTRACT1]] : $(Int, (Int, Int)), 0
// CHECK:   [[TUPLE_EXTRACT2:%.*]] = tuple_extract [[TUPLE_EXTRACT1]] : $(Int, (Int, Int)), 1
// CHECK:   [[RET_VAL2:%.*]] = tuple_extract [[TUPLE_EXTRACT2]]  : $(Int, Int), 0
// CHECK:   [[RET_VAL3:%.*]] = tuple_extract [[TUPLE_EXTRACT2]]  : $(Int, Int), 1
// CHECK:   [[RET_VAL4:%.*]] = tuple_extract [[TUPLE_APPLY]] : $(Int, (Int, (Int, Int)), Int), 2
// CHECK:   [[RET_VAL_TUPLE:%.*]] = tuple ([[RET_VAL0]] : $Int, [[RET_VAL1]] : $Int, [[RET_VAL2]] : $Int, [[RET_VAL3]] : $Int, [[RET_VAL4]] : $Int)
// CHECK:   return [[RET_VAL_TUPLE]] : $(Int, Int, Int, Int, Int)
// CHECK-LABEL: } // end sil function '{{.*}}'

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @{{.*}} : $@convention(thin) <T> (Int, @in T, @owned @callee_owned (@in (Int, T)) -> @out (Int, T)) -> (Int, @out T) {
// CHECK: bb0([[ARG0:%.*]] : $Int, [[ARG1:%.*]] : $T, [[ARG2:%.*]] : $@callee_owned (@in (Int, T)) -> @out (Int, T)):
// CHECK:   [[TUPLE_TO_APPLY:%.*]] = tuple ([[ARG0]] : $Int, [[ARG1]] : $T)
// CHECK:   [[TUPLE_APPLY:%.*]] = apply [[ARG2]]([[TUPLE_TO_APPLY]]) : $@callee_owned (@in (Int, T)) -> @out (Int, T)
// CHECK:   [[TUPLE_BORROW:%.*]] = begin_borrow [[TUPLE_APPLY]] : $(Int, T)
// CHECK:   [[RET_VAL0:%.*]] = tuple_extract [[TUPLE_BORROW]] : $(Int, T), 0
// CHECK:   [[TUPLE_EXTRACT:%.*]] = tuple_extract [[TUPLE_BORROW]] : $(Int, T), 1
// CHECK:   [[RET_VAL1:%.*]] = copy_value [[TUPLE_EXTRACT]] : $T
// CHECK:   end_borrow [[TUPLE_BORROW]] from [[TUPLE_APPLY]] : $(Int, T), $(Int, T)
// CHECK:   destroy_value [[TUPLE_APPLY]] : $(Int, T)
// CHECK:   [[RET_VAL_TUPLE:%.*]] = tuple ([[RET_VAL0]] : $Int, [[RET_VAL1]] : $T)
// CHECK:   return [[RET_VAL_TUPLE]] : $(Int, T)
// CHECK-LABEL: } // end sil function '{{.*}}'


// Tests LogicalPathComponent's writeback for opaque value types
// ---
// CHECK-LABEL: sil @_T0s10DictionaryV20opaque_values_silgenE22inoutAccessOfSubscriptyq_3key_tF : $@convention(method) <Key, Value where Key : Hashable> (@in Value, @inout Dictionary<Key, Value>) -> () {
// CHECK: bb0([[ARG0:%.*]] : $Value, [[ARG1:%.*]] : $*Dictionary<Key, Value>):
// CHECK:   [[OPTIONAL_ALLOC:%.*]] = alloc_stack $Optional<Value>
// CHECK:   switch_enum_addr [[OPTIONAL_ALLOC]] : $*Optional<Value>, case #Optional.some!enumelt.1: bb2, case #Optional.none!enumelt: bb1
// CHECK: bb2:
// CHECK:   [[OPTIONAL_LOAD:%.*]] = load [take] [[OPTIONAL_ALLOC]] : $*Optional<Value>
// CHECK:   apply {{.*}}<Key, Value>([[OPTIONAL_LOAD]], {{.*}}, [[ARG1]]) : $@convention(method) <τ_0_0, τ_0_1 where τ_0_0 : Hashable> (@in Optional<τ_0_1>, @in τ_0_1, @inout Dictionary<τ_0_0, τ_0_1>) -> ()
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T0s10DictionaryV20opaque_values_silgenE22inoutAccessOfSubscriptyq_3key_tF'

// Tests materializeForSet's createSetterCallback for opaque values
// ---
// CHECK-LABEL: sil [transparent] [fragile] @_T0s10DictionaryV20opaque_values_silgenE9subscriptq_Sgq_cfmytfU_ : $@convention(method) <Key, Value where Key : Hashable> (Builtin.RawPointer, @inout Builtin.UnsafeValueBuffer, @inout Dictionary<Key, Value>, @thick Dictionary<Key, Value>.Type) -> () {
// CHECK: bb0([[ARG0:%.*]] : $Builtin.RawPointer, [[ARG1:%.*]] : $*Builtin.UnsafeValueBuffer, [[ARG2:%.*]] : $*Dictionary<Key, Value>, [[ARG3:%.*]] : $@thick Dictionary<Key, Value>.Type):
// CHECK:   [[PROJ_VAL1:%.*]] = project_value_buffer $Value in [[ARG1]] : $*Builtin.UnsafeValueBuffer
// CHECK:   [[LOAD_VAL1:%.*]] = load [take] [[PROJ_VAL1]] : $*Value
// CHECK:   [[ADDR_VAL0:%.*]] = pointer_to_address [[ARG0]] : $Builtin.RawPointer to [strict] $*Optional<Value>
// CHECK:   [[LOAD_VAL0:%.*]] = load [take] [[ADDR_VAL0]] : $*Optional<Value>
// CHECK:   apply {{.*}}<Key, Value>([[LOAD_VAL0]], [[LOAD_VAL1]], [[ARG2]]) : $@convention(method) <τ_0_0, τ_0_1 where τ_0_0 : Hashable> (@in Optional<τ_0_1>, @in τ_0_1, @inout Dictionary<τ_0_0, τ_0_1>) -> ()
// CHECK:   return %{{.*}} : $()
// CHECK-LABEL: } // end sil function '_T0s10DictionaryV20opaque_values_silgenE9subscriptq_Sgq_cfmytfU_'
extension Dictionary {
  public subscript(key: Value) -> Value? {
    @inline(__always)
    get {
      return key
    }
    set(newValue) {
    }
  }
  
  public mutating func inoutAccessOfSubscript(key: Value) {
    func increment(x: inout Value) { }

    increment(x: &self[key]!)
  }
}
