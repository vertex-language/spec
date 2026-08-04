# Vertex Static Semantics

What the compiler accepts, and what it means. Syntax, lowering, IR, and library
surfaces are specified elsewhere; nothing here depends on them.

---

## 0. Scope of This Document

Where `grammar.md` says "static rule," the rule is here. The grammar deliberately
admits forms the language does not have, so that a reader gets a diagnostic naming
the construct rather than a parse failure; §11 lists every one of them and what it
is rejected as.

Checking proceeds in four passes, and a later pass never changes an earlier one's
answer:

| Pass | Decides | Specified in |
| --- | --- | --- |
| Select | which files are in the build | §1.2 |
| Parse | the shape of each file | `grammar.md` |
| Resolve | what every name denotes | §2 |
| Check | types, conventions, and markers | §3–§9 |

Two resolutions belong to the *Resolve* pass and are called out because they are
the only places meaning decides shape: `a[i]` is an instantiation or an index by
what `a` denotes (§5.4), and a name in a type-set position is a type or a
constraint by what it denotes (generics §3.3).

---

## 1. Programs, Packages, Files

### 1.1 Packages

A package is the set of selected files carrying the same `PackageName`. All of them
are compiled together, and **top-level declarations are order-independent**: a
declaration may reference any other in its package regardless of position or file.
Functions, methods, and types may therefore be mutually recursive without
forward declarations.

There is no visibility modifier in Vertex (grammar, *Declare blocks*). Every
top-level declaration in a package is reachable by any file that imports it.

### 1.2 Build Tags

A `BuildClause` is a *selection* rule, applied before parsing anything else:

* No clause — the file is in every build.
* A clause naming the target — the file is in this build.
* A clause naming another target — the file is out of this build entirely, and
  nothing in it is checked.
* An unrecognized tag — a compile error, never a silent exclusion (foundation §34).

Two constructs require a clause rather than merely permitting one:

| Construct | Requires | Because |
| --- | --- | --- |
| `declare framework` / `declare module` | any tag | linkage is derived from it (abstract_interfaces §0) |
| an `ExpectedType` result | `build test` | foundation §36.2 |

The diagnostic names the construct, not the missing clause.

### 1.3 Imports

Imports are **file-scoped**: an `import` in one file of a package does not bring the
qualifier into the others. The qualifier is the imported package's own
`PackageName`, never the path (foundation §30).

* The import graph must be acyclic. A cycle is a compile error naming the whole
  cycle.
* Two imports whose packages declare the same `PackageName` are a compile error;
  there is no aliasing form to resolve the clash with.
* An import no declaration in that file reaches is a compile error. Because file
  selection is whole-file (§1.2), an import can never be conditionally live.

### 1.4 `main`

A program has exactly one package named `main` declaring exactly one `func main()`
— no parameters, no result, no marker. It is the one non-`async` function in which
`await` is legal (async §2.2).

---

## 2. Names and Scopes

### 2.1 The Four Scopes

| Scope | Contains | Extent |
| --- | --- | --- |
| universe | predeclared names (§2.3) | every file of every package |
| package | every top-level declaration | every file of that package |
| file | the file's imported qualifiers | that file |
| local | parameters, type parameters, bindings, payload bindings | the construct that introduces them |

A local scope opens at every `Block`, at a `Signature`'s parameter list, at a
`TypeParameters` list, and at each `CaseClause`/`SelectClause` statement list. A
binding is visible from its declaration to the end of its scope; a type parameter is
visible across its entire list and the whole declaration that follows it
(generics §1).

Method names are not in any of these scopes — they are reached only through a
receiver, so a method `read` and a function `read` in one package do not collide.

### 2.2 Shadowing

An inner scope may shadow an outer one. Within a single scope a name is declared
once: two parameters, two fields, two type parameters, or two locals in one block
with the same spelling are an error.

**Vertex has no overloading.** One name denotes one declaration. The multiple `func`
lines shown for `new` (memory §11.1) describe builtin call shapes, not declarations
a user can write.

### 2.3 Predeclared Names

The universe scope holds four families, each with its own legality rule. All are
ordinary identifiers — no scanner recognizes them.

| Family | Names | Legal |
| --- | --- | --- |
| Types | `int`…`uint64`, `byte`, `float32/64`, `bool`, `char`, `string` | wherever a `Type` is |
| Constraints | `any`, `comparable` | only in a `"["`…`"]"` position, never as a `Type` |
| Tensor element types | `bf16`, `fp8e4m3`, `fp8e5m2`, `int4` | only inside an `npu` body (accel §2.2) |
| Reserved builtins | `new delete resize copy zero addr sizeof alignof reinterpret upgrade drop panic blend min max clamp transfer` | callable per their own documents |

`int` and `uint` are the target's pointer width and are distinct types from
`int64`/`uint64` even where the widths agree. `byte` is an alias for `uint8`, not a
distinct type (foundation §4.1). `char` is one Unicode scalar value.

**Reserved builtin names may not be shadowed** — not as a local, parameter, type
parameter, field, method, or top-level declaration, and not as a parameter label
(memory §11.1). That guarantee is what lets `sizeof`, `alignof`, and `reinterpret`
be recognized by name in a `TypeOperatorCall`. Every other predeclared name is
shadowable in an inner scope, and doing so is a lint, not an error.

`transfer` is reserved and bound to nothing, so `x.transfer()` and `transfer(x)`
diagnose against ownership §3.3 rather than as unknown names.

### 2.4 The Blank Identifier

`_` is an ordinary `identifier` token that introduces no binding and may be
repeated freely. It is accepted, and means "discard," in exactly these positions:

```vertex
var _: int32                  // declaration
let a, _ = pair               // destructure
_ = compute()                 // assignment target
case .Color(r, _, _):         // payload binding
func f[_, T](x: T)            // unused type parameter
for _, n in nums              // iteration binding
```

Anywhere else — a field name, a package name, a parameter name, a method name, a
selector, a type name — `_` is an error. Reading `_` is always an error: it names
nothing.

---

## 3. Types

### 3.1 Identity

Declared types (`struct`, `class`, `enum`) are **nominal**: two declarations are
distinct types even with identical fields, and each `abstract` alias is distinct
from every other (abstract_interfaces §1).

Type literals are **structural**: two `func` types are the same type when their
parameter types, marker, and result agree — parameter *names* are not part of the
type (foundation §31). `[N]T` carries `N` in its identity; `[8]int32` and
`[16]int32` are unrelated.

A `TypeAliasDecl` introduces a second name for one type, interchangeable with the
first in both directions and at every depth of composition. The distinction between
an alias and its target survives in exactly one place: a type set, where a bare `T`
admits `T` only and `~T` admits every type whose **underlying type** is `T`
(generics §3.1). A declared type's underlying type is the type its declaration
names; a type literal's underlying type is itself.

### 3.2 Where a Type May Appear

| Type | Legal position |
| --- | --- |
| `mut T`, `var T` | a parameter or receiver only — including a `func` type's parameters; never a result, field, local, or type argument |
| `unique T`, `shared T`, `weak T` | anywhere a `Type` is |
| `typed_ptr T` | anywhere a `Type` is, but never the direct base of another `PointerType` (memory §2.1), and never a receiver type |
| `chan T` | anywhere a `Type` is |
| `tensor[T, …]` | inside an `npu` body or that function's own signature (accel §2.2) |
| `vector[T, N]` | anywhere except a `gpu`/`npu` body or signature, a foreign boundary, or a map key (accel §3.4) |
| `abstract` | only as the target of a `TypeAliasDecl` |
| a constraint name | only in a `"["`…`"]"` position |
| `Expected(…)` | only as a `FunctionDecl`/`MethodDecl` result, in a `build test` file |

Ownership qualifiers do not stack: `mut shared T` parses (the recursion is
unguarded) and is rejected as a stacked qualifier.

A `ReceiverType` is a `TypeName`, so a method may be declared only on a struct,
class, or enum **declared in the same package**. There are no methods on type
literals, on predeclared types, or on imported types.

### 3.3 Zero Values

Every type has a zero value, so there is no definite-assignment analysis anywhere in
the language. A declaration with a type and no initializer *is* its zero value, which
is what foundation §35.5 and generics §6 rely on.

| Type | Zero |
| --- | --- |
| numeric | `0` |
| `bool` | `false` |
| `char` | U+0000 |
| `string` | `""` |
| struct, class | every field zeroed — field **defaults are not applied**; they belong to construction (§7.2) |
| `[N]T`, tuple, `vector`, `tensor` | elementwise zero |
| enum | the first declared variant, with any payload zeroed |
| `[]T`, `map[K]V` | empty |
| `typed_ptr T` | `nil` (memory §13) |
| `func` type | an unset function; calling it panics |
| `chan T` | a closed, empty channel |
| `unique T`, `shared T`, `weak T` | an empty handle; reading through it panics, and `upgrade` of a zero `weak` reports failure |
| `abstract` | the zeroed representation — legal **only** on an error path, paired with a non-empty string (abstract_interfaces §2) |

The only memory in a Vertex program that is not zero-initialized is a block from
`new(…, zeroed: false)` (memory §11.1).

### 3.4 Size and Recursion

Every type has a size known at compile time. A type may not contain itself by value,
directly or through a cycle of struct/class/array/tuple fields — the size would not
terminate. Break the cycle with an indirection, all of which are one word:
`unique T`, `shared T`, `weak T`, `typed_ptr T`, `[]T`, `map[K]V`, or `chan T`.

Recursive *instantiation* must terminate for the same reason (generics §8).

### 3.5 `comparable` and `Ordered`

`==` and `!=` require a type satisfying `comparable`; `<`, `<=`, `>`, `>=` require
`constraints.Ordered`.

| | Members |
| --- | --- |
| `comparable` | numerics, `bool`, `char`, `string`, `typed_ptr T`, enums, and any struct, class, tuple, or `[N]T` whose every component is comparable |
| `Ordered` | numerics and `string` (generics §4) |
| neither | `[]T`, `map[K]V`, `chan T`, `func` types, `vector`, `tensor`, `abstract`, and the three heap handles |

`==` on a class compares values; `===` asks whether two bindings name the same
object and is legal on classes only (foundation §14). `==` on a `typed_ptr` already
compares addresses, so `===` does not apply to one.

---

## 4. Assignability and Conversion

### 4.1 Assignability

A value is assignable to a destination when their types are **identical** (§3.1).
There is no subtyping, no coercion, and no promotion. A marker is part of a `func`
type, so a `func(int32)` is not assignable to a `func(int32) async`.

Two things relax this, both narrow:

1. **Untyped literals.** A literal has no type until it lands; where a destination
   type exists the literal takes it, and where none does it falls back to the
   defaults in foundation §6.1. A literal whose value does not fit its destination
   is a compile error, not a wraparound. This applies to literals only — the moment
   a value has been bound, returned, or read, §4.2 governs.
2. **The two stated implicit conversions**, both scoped and both listed in §4.3.

### 4.2 Conversion — `as`

Every width, signedness, or representation change between *values* is written
(foundation §6).

| From → to | Meaning |
| --- | --- |
| integer → integer | truncates or sign-extends; the written form is the permission |
| float → integer | truncates toward zero; a value outside the destination's range traps (§5.5) |
| integer → float | rounds to nearest, ties to even |
| enum → its discriminant type | one-way only; there is no `n as Status` (foundation §26.4) |
| `typed_ptr T` → `typed_ptr U` | static reinterpretation, never a read (memory §7) |
| `typed_ptr T` ↔ integer | address value, never inferred |
| `abstract` → `typed_ptr T` | only where linkage is memory-flat (memory §8); never the reverse |

The predeclared numeric types do not take the constructor spelling — write
`i as float32`, not `float32(i)`. The tensor element types are the single exception:
`bf16(val)` is the form there, and `val as bf16` is not (accel §2.4).

### 4.3 The Two Implicit Conversions

| Where | What | Bounded by |
| --- | --- | --- |
| a `gpu`/`npu` launch site | `[N]T` ↔ `tensor[T, N]`, element type and shape matching exactly | the launch expression itself (accel §2.1) |
| a pointer cast with a written destination | `typed_ptr T` → `typed_ptr U` with `as` elided | both sides pointer types (memory §7) |

Neither reaches inside a body, and no third case is added anywhere.

---

## 5. Expressions

### 5.1 Operand Rules

| Operator | Operands | Result |
| --- | --- | --- |
| `+ - * / %`, unary `-` | one numeric type, both sides identical | that type |
| `+` on `string` | two `string` | `string` (concatenation) |
| `&+ &- &*` | one integer type | that type, wrapping |
| `& \| ^ ~` | one integer type | that type |
| `<< >>` | integer left, integer right | the left type |
| `== !=` | one `comparable` type | `bool` |
| `< <= > >=` | one `Ordered` type | `bool` |
| `=== !==` | two values of one class type | `bool` |
| `&& \|\| !` | `bool` only, short-circuiting | `bool` |
| `..` | one integer type, non-associative | not a value (§5.2) |
| `as` | a value and a `Type` | the `Type` |
| `&` | a value, or a `typed_ptr T` | address-of, or `T` |

There is no promotion and no truthiness: an `if`, `while`, or `&&` operand must be a
`bool`, and a non-empty integer is not one.

Elementwise operators on tensors and lane-wise operators on vectors are the two
places these rules widen, and both are specified in `accel.md` (§2.3, §3.3). A
`vector` comparison yields a lane predicate, which has no source spelling and may
not be an `if` condition, a `&&` operand, a field, or a channel element.

### 5.2 Ranges Are Not Values

`a..b` has no type and cannot be bound, returned, passed, or stored. It is
admissible in exactly three positions (foundation §13): a `for`'s iterable, a
bracket position where it makes a slice, and a `switch` case. Both endpoints are one
integer type; the range is always exclusive of `b` and empty when `a >= b`.

### 5.3 Constant Expressions

A constant expression is a literal, a unary or binary operation over constant
expressions, an `as` conversion of one, `sizeof`/`alignof`, or an enum discriminant.
It contains no call, no binding, and no field read. Constants are required in:

* an `ArrayLength` — and it must be a non-negative integer,
* an enum's explicit discriminant,
* a top-level `VarDecl` initializer,
* a `switch` case pattern,
* `new`'s `align:` argument, where it must be a power of two.

Three positions are stricter still and require a bare *literal token*, which is why
`-1000` — unary minus over a literal — is not admissible in any of them
(foundation §1): a `ShapeList`, a `VectorType`'s lane count, and a `TupleIndex`.
A `TupleIndex`'s literal must additionally be decimal with no `"_"`.

### 5.4 Calls

* Arity must match. A variadic parameter absorbs zero or more trailing arguments of
  its element type.
* Arguments are positional or named; a named argument uses the parameter's declared
  name. **A single call may not mix the two forms.**
* Named arguments may be written in any order; positional ones may not.
* The callee's marker fixes the call form (§7.4).
* `Stack[int32]` is an instantiation and `a[i]` an index, decided by whether the
  operand denotes a generic declaration (generics §5.4). An `Index` on a
  non-generic, non-indexable operand is an error naming both readings.

### 5.5 Trapping

These are checked at runtime and abort the program (§10). They are not the error
tuple, because none of them is a condition a caller could have handled:

| Form | Trap |
| --- | --- |
| overflow of `+ - * /` or unary `-` | yes — use `&+ &- &*` to wrap |
| division or `%` by zero | yes |
| a shift count at or beyond the left operand's width | yes |
| `[]T` / `[N]T` subscript out of range | yes (foundation §22.4) |
| a constant subscript provably out of range on a `[N]T` | compile error instead |
| a `vector` load whose window runs past a fixed array | compile error if constant, trap if not |
| `float → int` conversion out of range | yes |
| container allocation failure | yes (foundation §22.2) |

`typed_ptr` operations are the opposite tier and check nothing (memory §14.3).

---

## 6. Statements

### 6.1 Declarations

`let` requires an initializer and fixes the *binding*; `var` may be rebound and is
required by anything taking exclusive access or transferring. Neither says anything
about the value: a `let`-bound class's fields are still writable through a `mut`
method, but the binding must be `var` for that call (foundation §2).

A `var` with a type and no initializer is that type's zero value (§3.3). A bare
`var w` — no type, no initializer — is an error: there is nothing to infer from.
When `w` also names a live binding, the diagnostic is the more useful one, *transfer
outside owning position*, which is precisely why the grammar gives the form a
declaration node to hang it on.

A top-level `VarDecl` takes a constant initializer (§5.3), and the bare
`"var" Binding` form is rejected there outright.

Binding lists and initializer lists must agree in count, either one-to-one or as a
single call whose result tuple has that arity (foundation §29.5).

### 6.2 Assignment

An `AssignTarget` is a `PrimaryExpr`, and it is assignable when it is:

* a `var` binding,
* a field of an assignable value, or of any class or `shared`/`unique` handle,
* an element of an assignable `[N]T`, or of any `[]T` or `map[K]V`,
* a dereference `&p` of a `typed_ptr`,
* the blank identifier.

Everything else — a `let` binding, a call result, a slice of a shared view, a tuple
index of a temporary — is not. Assignment is a statement, so no `=` appears in any
condition in the language.

The right-hand side of an assignment is an owning position (§8.2).

### 6.3 Control Flow

* `if` and `while` conditions are `bool`. `if` has no initializer clause.
* `for` iterates a range, `[N]T`, `[]T`, `map[K]V`, or `string`, and nothing else —
  there is no user-extensible iterator protocol. The two-name form is
  index/value for arrays, key/value for maps.
* The `IterationBinding` marker and the two-name form do not combine, and `var` on
  the *iterable* rather than the binding is rejected (foundation §21.2).
* `break` and `continue` apply to the innermost loop; there are no labels. Neither
  is admissible in an `npu` body (accel §2.5).

### 6.4 Switch

* Every pattern must be assignable to the subject's type, and constant (§5.3).
* Two clauses may not match a common value the compiler can see — duplicate
  constants and overlapping constant ranges are errors.
* A `switch` over an enum must be **exhaustive**: cover every variant or write
  `default`. Every other switch may fall out the bottom.
* At most one `default`, in any position.
* `fallthrough` must be the last statement of a non-final clause, and the clause it
  falls into may not bind payloads — there would be nothing to bind them from.
* An `EnumPattern`'s payload entries are fresh binding names scoped to that clause,
  and are **views** into the payload, not copies. They may not be assigned through.

### 6.5 Select

The rules are stated in `channels.md` §4 and are static rules in full:

1. Every case is `.receive()` or `.tryReceive()` on a `chan T`.
2. One statement is entirely bare or entirely `await`ed.
3. At most one `default`, which makes the whole statement non-blocking.
4. Bindings introduced by a `ChannelCase` are scoped to that clause.

### 6.6 Return and Defer

A `ReturnStmt`'s expression list must match the enclosing signature's result slot
for slot. A call yielding a tuple cannot be forwarded whole into a multi-slot
result — destructure first (foundation §29.6). A function with no result may write
`return` bare and must not write a value.

`defer` takes a call. Its callee and arguments are evaluated at the `defer`
statement; the call runs when the enclosing function returns, in reverse order of
registration. Deferred calls do not run on `panic` (§10).

---

## 7. Functions, Methods, and Markers

### 7.1 Signatures

* Parameter names in one `Parameters` list are all present or all absent. A bare
  `FunctionType` names types only.
* At most one variadic parameter, and it is last.
* A signature carries **at most one** `FunctionMarker`. More parses and is rejected.
* Omitting the result is the void form; there is no `void` type and no unit type.

### 7.2 Receivers, Construction, and Destruction

| Receiver | Meaning | Call site |
| --- | --- | --- |
| `(x: T)` | shared, read-only | bare |
| `(x: mut T)` | exclusive; the binding must be `var` | bare |
| `(x: var T)` | consuming — always transfers | bare; there is no second form to pick |
| `(x: shared T)` | shared handle | bare |

A method may **not** declare its own `TypeParameters`; a receiver's list re-declares
the receiver type's existing names rather than introducing fresh ones (generics §9).
A constraint written on the type is in force inside every method and is not restated.

`init` and `deinit` are ordinary method names recognized by spelling:

* Both receivers are implicitly exclusive and written bare — an explicit qualifier
  on one is an error.
* `init` declares no result; **an initializer has no error channel** (foundation
  §27). A construction that can fail is an ordinary function returning a boundary
  tuple.
* `deinit` takes no parameters and declares no result.
* At most one of each per type.

**Construction.** A struct is built by a composite literal; a class is built by
calling an initializer, and `Animal{}` constructs nothing. A composite literal must
name each field without a default exactly once, may name them in any order, and may
not name a field the type does not have. Field defaults are evaluated at each
construction for each omitted field, and may not reference other fields or the
value under construction.

**Destruction.** A value dies at the end of the block that declares it, in reverse
order of declaration; a field dies with the value that holds it, in reverse order of
declaration. `deinit` runs first, then the fields. A binding that has been
transferred away is already dead and is not destroyed again (§8.3).

### 7.3 Closures

A function literal captures by value at creation. Reading a captured binding is
legal; **writing one is a compile error** — the copy is not the original
(foundation §32). Write-back goes through a `mut` parameter.

A function literal begins with all enclosing parse context cleared: an inner body
that awaits must carry its own `async` marker. A closure that captures anything at
all may not cross a foreign boundary, even read-only
(abstract_interfaces §6).

### 7.4 Markers and Call Forms

The marker is part of the function's type, so it is checked at the declaration and
again at every call. **The marker must agree at both ends**: a marked function
cannot be called bare, and an unmarked one cannot be called with a launch prefix.

| Marker | Legal call forms |
| --- | --- |
| none | `f(x)`, `thread f(x)` |
| `async` | `await f(x)`, or `async f(x)` to spawn |
| `gpu` | `gpu f(x)`, `gpu(blocks: b, threads: t) f(x)` |
| `npu` | `npu f(x)` |
| `test` | none — the harness invokes it |

Further rules:

* `await` is legal only inside an `async`-marked body or `main` (async §2.2). Its
  operand is a call to an `async`-marked function or a channel receive.
* `thread` takes an unmarked callee. `thread` over a marked one is an error.
* A launch prefix modifies scheduling only; it never changes the callee's signature.
* `gpu` and `npu` launches are synchronous and hand back a host-typed value;
  `thread` and `async` hand back a `chan T` (channels §0).
* A `LaunchConfig` writes both `blocks:` and `threads:`, in that order.
* `async`, `gpu`, and `npu` followed by `"."` are namespace references, not prefixes
  (accel §0.2).
* A `test` function takes no parameters, carries an `Expected` result or none, and
  exists only in a `build test` file.

---

## 8. Values, Ownership, and Lifetime

`ownership.md` is the full treatment. This section states the parts the checker
enforces.

### 8.1 Conventions

The convention lives in the signature; only the owning one has a choice at the call.

```vertex
func f1(x: T)          // shared    — bare, caller keeps the value
func f2(x: mut T)      // exclusive — bare, caller's binding must be `var`
func f3(x: var T)      // owning    — bare copies, `var` transfers
```

### 8.2 The Transfer Marker

`"var"` in expression position is legal only in an **owning position**: the
right-hand side of a declaration or assignment, an argument, an element of a
tuple/array/map/composite literal, a returned expression, or a consuming `for`
binding. Owning-ness does not propagate into subexpressions.

Its operand must be a binding or a field path. `var f(a)` and `var items[0]` parse
and are rejected — there is nowhere for a transfer out of a temporary or an element
to leave a hole.

### 8.3 Liveness

* A transferred binding is dead. Any later use is an error naming the transfer.
* Transfers chain, and each kills its source.
* A binding transferred on *some* paths is treated as transferred on all of them.
* A transfer in a loop body is rejected outright: the second iteration would move a
  dead binding.
* Within one call, a binding may not be transferred twice, nor transferred and read.

Neither rule evaluates a condition or a trip count. Both are positional.

### 8.4 Exclusivity

No two arguments of one call may reach the same value if either is `mut`, and the
receiver counts as one of the paths — which is what catches an overlap running
through a field (ownership §9).

`typed_ptr T` is the one type these rules do not reach. Two copies are two unchecked
aliases, and exclusivity there is convention rather than proof.

### 8.5 Cost

| Type | Bare copy | `var` transfer |
| --- | --- | --- |
| scalars, `typed_ptr T` | register move | same; source marked dead |
| struct, class, `[N]T` | fieldwise copy | header move, O(1) |
| `string`, `[]T`, `map[K]V` | deep-copies the payload | O(1) |
| `unique T` | allocates and deep-copies the pointee | O(1) |
| `shared T`, `chan T` | refcount increment | O(1), no count change |
| `weak T` | weak-count increment | O(1) |

Under generics the cost is fixed by the concrete type at instantiation, so a lint on
large owned types fires per instantiation, not per declaration.

---

## 9. Generics and Constraints

`generics.md` is the specification; three rules matter to every other document.

1. **The declaration is checked once, on its own terms.** The operations available
   on a `T` are exactly those its constraint permits, whatever the instantiations in
   the program happen to supply. Under `any` that is assignment, argument passing,
   and the ownership operations — no `<`, no `==`, no `+`, no field access.
2. **Constraint satisfaction is checked per instantiation**, at the instantiation
   site, and a failure is a compile error there.
3. **Inference either succeeds or fails.** A type parameter appearing only in the
   result must be supplied explicitly. `new` and `resize` are the one stated
   exception, scoped to a destination whose pointer type is already written down
   (memory §11.1).

A `ConstraintDecl` takes no type parameters, is legal only in a `"["`…`"]"`
position, and is never a value type. Multiple elements in its body are an
intersection; `|` within one element is a union.

---

## 10. Errors, Panics, and Undefined Behaviour

Vertex has three tiers, and nothing moves between them.

| Tier | Shape | For |
| --- | --- | --- |
| Condition | the boundary tuple — `(T, string)`, or a bare `string` (foundation §35) | anything a caller could reasonably handle: I/O, parsing, absence, allocation through `new` |
| Bug | `panic(string)` and the traps of §5.5 | a broken invariant: a bad index, an overflow, an exhausted container |
| Undefined | nothing | `typed_ptr` misuse only (memory §14.3) |

Absence and failure share the tuple channel; there is no optional type, no
propagation operator, and no general `nil`. `nil` belongs to `typed_ptr T` and to
nothing else.

`panic` does not return. It terminates the program: deferred calls do not run, no
`deinit` runs, and there is no catch, recover, or unwind. That is what makes the
first tier the only one worth writing recovery code against — and it is why the
compiler does **not** enforce that a caller checks the error string. The convention
is explicit-over-automatic in both directions.