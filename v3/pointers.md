# pointers.md

## Managed Allocation (Tier 1)
Default and only form in the Managed tier. No pointer syntax exists at this tier — `class`
allocation is ARC'd invisibly by the compiler, and `struct` construction is a stack value.
Neither reads any differently from the other at the call site.

```vertex
var a = Sample001();
```

Whether `Sample001` is a `struct` or `class` determines what happens underneath — value
construction versus a compiler-inserted retain — but nothing at the call site marks the
difference. This is deliberate: `arch_v2.md`'s Managed tier locks the pointer family away
entirely, so there is nothing to spell.

## Owning Pointer Types (Tier 2)
Refcounted or single-owner smart pointers over `class` allocations. Only nameable in the
Unmanaged tier — a Managed-tier file has no route to write these types, since nothing in
scope produces one.

```vertex
let a: shared_ptr<Sample001>;
let b: unique_ptr<Sample001>;
let c: weak_ptr<Sample001>;
```

## Unmanaged Pointer Types
Raw C FFI-boundary pointers. Released by nobody — ownership is manual.

```vertex
let a: mutable_ptr<Sample001>;
let b: const_ptr<Sample001>;
let c: void_ptr;
```

## Construction Calls
Type as an explicit type argument, constructor arguments forwarded through — the object is
built in place inside the allocation, not constructed separately and then wrapped. Same
shape `std::make_unique`/`std::make_shared` use in C++, and ordinary generic-call grammar
already legal elsewhere in the language — no new syntax.

```vertex
var b = make_unique<Sample001>(0, 0);
var c = make_shared<Sample001>(0, 0);
```

`unique_ptr` has no other construction route — there is no bare `unique_ptr<Sample001>()`
that constructs first and wraps second. `shared_ptr` is likewise always produced this way
in the Unmanaged tier; the Managed tier's `var a = Sample001()` is a separate, unrelated
path that never surfaces the type name at all.

## Weak Pointer Derivation
`weak_ptr<T>` is never allocated directly — only derived from an existing `shared_ptr<T>`.
Unaffected by the `make_*` forms above, since it does not allocate.

```vertex
var a = make_shared<Sample001>(0, 0);
var b = weak_ptr(a);
```

## Weak Pointer Lock
Access to the pointee goes through `.lock()`, returning a nullable shared pointer.

```vertex
var a: shared_ptr<Sample001> | null = b.lock();
```

## Addressof
Produces a raw pointer from a stack lvalue.

```vertex
var a: int32 = 0;
var b: mutable_ptr<int32> = addressof(a);
```

## Nullable Raw Pointer
Raw pointers are non-nullable by default; absence is spelled as an explicit union.

```vertex
var a: mutable_ptr<Sample001> | null;
```

## Managed/Unmanaged ABI Parity
Per `arch_v2.md`, the native Managed tier's compiler-inserted retain and the Unmanaged
tier's `shared_ptr` speak the same ABI — same layout, same refcount mechanics. A bridged
reference crossing the boundary is a pointer handoff, not a translation. This is what makes
`make_shared<Sample001>(...)` in Unmanaged code and `Sample001()` on a `class` in Managed
code interchangeable at the boundary, and it is the reason `shared_ptr`/`weak_ptr` keep one
definition rather than needing a per-tier variant.

## Grammar Cost
Zero. `make_unique<T>(...)`/`make_shared<T>(...)` are ordinary calls with explicit
`TypeArguments`; `weak_ptr(a)` is an ordinary call; the pointer types are ordinary generic
type references. Tier enforcement — which names are in scope — is semantic, not syntactic.