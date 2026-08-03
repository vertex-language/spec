# Vertex Static Semantics

What the compiler accepts, and what it means. Syntax, lowering, IR, and library
surfaces are specified elsewhere; nothing here depends on them.

---

## 0. Terms

**Error** — the compiler must reject. **Unspecified** — one of several defined
outcomes, none guaranteed. **Undefined** — no guarantee, nothing checks. Raw
pointer operations are the only source of undefined behavior.

**Owning position** — where a value becomes someone else's responsibility.
Exactly six: the right-hand side of a declaration or assignment, an argument, an
element of a tuple / array / map / composite literal, a returned expression, and
the binding of a consuming `for` loop. Owning-ness does not propagate into
subexpressions.

**Build tag** — a per-file target selector: `linux`, `windows`, `darwin`, `js`,
`wasm`, `test`.

**Boundary tuple** — the return shape `(T, string)`, the string empty on
success. The only spelling for fallible or absent.

**Marker** — `async`, `gpu`, `npu`, or `test` on a function signature.

---

## 1. Names and Scope

1. Scopes nest: package → file → function → block → statement.
2. A declaration is visible from its declaration point to the end of its
   enclosing block.
3. Package-level declarations are visible throughout the package regardless of
   order. Inside a function body, forward reference is an error.
4. Redeclaring a name in one scope is an error. Shadowing is legal and silent.
5. `_` declares nothing, binds nothing, and may not be read.
6. A `declare` block introduces no scope: members are injected into the
   enclosing package. Collision with a package-level name is an error.
7. `build`, `init`, `deinit`, `error`, `framework`, `module`, and `test` are
   ordinary identifiers outside the productions that name them.
8. Reserved; not declarable as members, locals, or parameters: `new`, `delete`,
   `resize`, `copy`, `zero`, `addr`, `sizeof`, `alignof`, `reinterpret`,
   `upgrade`, `unique`, `shared`, `weak`, `drop`, `panic`, `blend`, `min`,
   `max`, `clamp`.

---

## 2. Types

### 2.1 Identity

1. Types are **nominal**. Two named types are identical only if they are the
   same declaration.
2. `type N = T` declares a new type whose **underlying type** is `T`'s
   underlying type. `N` and `T` are never identical.
3. `byte` is the sole transparent alias, of `uint8`: identical type,
   interchangeable in both directions.
4. Composite types are identical iff their components are identical, and for a
   fixed array iff the lengths are equal.
5. Each `type X = abstract` is a distinct type with no underlying type. Two
   abstract types never unify.
6. Two instantiations are identical iff the generic declaration and every type
   argument are identical.

### 2.2 Underlying type

The underlying type of a predeclared or composite type is itself; of a declared
alias, the underlying type of its target. Consulted in exactly two places: `~T`
in a constraint type set, and rule 2.1.2.

### 2.3 Assignability

`V` may be assigned to a location of type `T` iff `V` and `T` are identical, or
`V` is an untyped constant representable in `T`, or one of the two is `byte` and
the other `uint8`, or `T` is a raw pointer type and `V` is `nil`.

No implicit widening, no implicit conversion between a named type and its
underlying type, no subtyping. This governs `vector[T, N]` unchanged: no
widening between vector types differing in `T` or `N`, and no conversion between
a vector and its element type.

### 2.4 Ownership qualifiers

`mut`, `var`, `unique`, `shared`, and `weak` qualify a type; none is a type.

1. `mut T` and `var T` are legal only in parameter and receiver position. In a
   field, local, return type, or type argument they are an error.
2. `unique T`, `shared T`, `weak T` are ordinary types, legal wherever a type is.
3. Qualifiers do not stack: `mut var T`, `unique unique T`, `mut shared T` are
   errors.
4. A `weak T` is constructible only from a `shared T`.

### 2.5 Zero values

Every type has a zero value: numeric zero, `false`, the empty string, the null
character, a recursively zeroed struct or class, `nil` for a raw pointer, empty
for a dynamic array or map, the first-declared variant for a unit enum, a zeroed
handle for an abstract type, and `N` zero lanes for a `vector[T, N]`.

`unique T`, `shared T`, and `weak T` have **no** zero value. Declaring one
without an initializer is an error, as is using one where a zero value is
required.

An abstract handle's zero value is legal only as the value half of a failed
boundary tuple, paired with a non-empty string. It is not comparable to `nil`
and has no null-check form.

---

## 3. Constants

### 3.1 Untyped constants

Literals are untyped until used.

1. An untyped constant takes the type of its context if representable there.
   `let b: int8 = 300` is an error.
2. With no contextual type: integer → `int32`, float → `float64`, string →
   `string`, char → `char`, bool → `bool`.
3. `nil` is not a value and has no type; its two admissible positions are §6.7.

### 3.2 Constant expressions

Required for: fixed array lengths, tensor shapes, vector lane counts, enum
discriminants, test expectation strings, interop variant tags.

A constant expression is a literal, a reference to a constant-initialized
declaration, a size or alignment query, or an operator applied to constant
expressions. Anything else in these positions is an error. Constant arithmetic
that overflows its target type is an error, not a wrap — unlike runtime
arithmetic, which wraps silently.

---

## 4. Bindings

| | mutable | addressable | may feed `mut` | reassignable |
| --- | --- | --- | --- | --- |
| `let` | no | no | no | no |
| `var` | yes | yes | yes | yes |

1. Assigning to a `let` binding, or to a field reached through one, is an error.
2. Passing a `let` binding to a `mut` parameter or receiver is an error: it is
   not guaranteed to have an address.
3. **Definite assignment.** Reading a binding is legal only if every path from
   its declaration assigns it first. A `var` declared with a type and no
   initializer counts as assigned, to that type's zero value.
4. A declaration with neither initializer nor type annotation is an error.
5. A multi-value destructure requires exact arity; `_` may absorb an element.
6. A `let` binding may still be transferred — a transfer ends liveness rather
   than mutating.

---

## 5. Ownership

### 5.1 Conventions

A parameter or receiver declares exactly one:

| Form | Callee receives | Call site |
| --- | --- | --- |
| `x: T` | shared access — read-only alias | bare |
| `x: mut T` | exclusive access — mutating, non-owning | bare |
| `x: var T` | ownership | bare for a copy, `var` for a transfer |

Shared and `mut` call sites never carry a marker; writing one is an error.

### 5.2 The `var` marker

At an owning position, applied to an existing binding or field path: prefixed
with `var` it **transfers** (source dies, destination becomes sole owner); bare
it **copies** (source stays live, destination independent).

1. `var` is legal only at an owning position.
2. `var` applies to an identifier or field path only. On a call, an index, an
   arithmetic expression, or any other computed value it is an error.
3. A freshly constructed value has no prior owner; the temporary is consumed
   unconditionally.
4. A `var` receiver has no argument slot for a marker, so calling such a method
   **always** transfers the receiver — the only unmarked transfer in the
   language. To keep the original, bind a copy first and call on that.
5. Copying is not callable. It is what happens when `var` is absent.

### 5.3 Liveness

1. Using a binding after it has been transferred is an error.
2. Liveness is flow-sensitive. If *any* path reaching a use transfers, the use
   is an error. No runtime flag is inserted.
3. Transferring, inside a loop body, a binding declared outside that loop is an
   error.
4. One call may not transfer the same binding twice, nor read it while
   transferring it.
5. Transferring a field makes the whole enclosing binding unusable. There is no
   partial-move re-initialization.

### 5.4 Exclusivity

**Law:** aliasing or mutation over one region, never both at once.

1. Two arguments of one call may not both be `mut` over overlapping storage.
2. A `mut` argument may not overlap a shared argument of the same call.
3. A `mut` argument may not overlap the receiver.
4. Overlap is computed over field paths. `a` and `a.b.c` overlap; `a.b` and
   `a.c` do not; two subscripts of one container are assumed to overlap.
5. A slice view is a live shared borrow of the buffer it views: while the view
   is live, mutating or transferring that buffer is an error. When the view is
   the destination of `copy` writing a vector store (§10.4), or is passed to a
   `mut` parameter, it holds a `mut` borrow instead. The two borrow kinds are
   mutually exclusive on one view.
6. Exclusivity is checked entirely statically.

### 5.5 What a copy costs

1. A thin value copies by register move. `vector[T, N]` and the lane predicate
   are thin: no deep-copy path, and `var` transfer on either is legal and
   identical to a copy in emitted code, though the marker still affects
   liveness.
2. An owning fat value — string, dynamic array, map, capturing closure, unique
   heap value — duplicates its payload.
3. A slice view duplicates the view, never the buffer.
4. A `shared T` copies the handle only.
5. An **abstract handle cannot be copied**: accessed or transferred only. A bare
   copy at an owning position is an error.
6. Neither a vector nor a lane predicate has a teardown; a struct or class
   containing one is not thereby non-trivial to tear down.
7. Cost never affects legality. An expensive copy is a lint.

### 5.6 Heap and weak references

1. `unique(e)` and `shared(e)` consume `e` as construction; the copy/transfer
   reading does not apply.
2. `shared(u)` promoting a unique value is the only promotion. There is no path
   back.
3. `weak(a)` requires a `shared T`. A weak reference to a unique value, a stack
   value, or a raw pointer is an error.
4. `upgrade(w)` requires a `weak T` and yields `(shared T, string)`.
5. Reaching a weak reference's payload without `upgrade` is an error.
6. A `deinit` body may reach its owner only through `upgrade`.

---

## 6. Expressions

### 6.1 Operators

| Operator | Requires | Yields |
| --- | --- | --- |
| `+ - *` | one identical numeric type, or one identical `vector[T, N]` | that type |
| `/` | one identical numeric type, or one identical float `vector[T, N]` | that type |
| `%` | one identical numeric type | that type |
| `&+ &- &*` | one identical integer type, or one identical integer `vector[T, N]` | that type, wrapping |
| `& \| ^ ~` | integer operands, or one identical integer `vector[T, N]` | the left operand's type |
| `<< >>` | integer operands (count may be any integer), or an integer `vector[T, N]` with an integer scalar count | the left operand's type |
| `== !=` | identical types | `bool`, except two identical `vector[T, N]`, which yield a lane predicate (§10.5) |
| `< <= > >=` | identical ordered types: numeric, string, char; or two identical `vector[T, N]` | `bool`, except the vector case, which yields a lane predicate (§10.5) |
| `=== !==` | two values of one class type | `bool` |
| `&& \|\| !` | `bool` | `bool` |
| `..` | identical integer types | a range |

1. Mixed-type arithmetic is an error; write a conversion. This includes mixing a
   vector with its own element type — there is no broadcasting, only the
   explicit splat constructor (§10.4).
2. `%` on floats is an error. `/` and `%` on an integer vector are both errors:
   no mainstream target has either as a single instruction.
3. `===` on a struct, enum, primitive, vector, or lane predicate is an error.
   Identity is a class-only question.
4. `&&` and `||` short-circuit; that is their only dynamic property.
5. Division or remainder by a constant zero is an error. By a runtime zero, a
   scalar traps; a float vector does not — IEEE division by zero produces an
   infinity, lane-wise.
6. A range is exclusive of its upper bound, and empty when the lower bound is
   not less than the upper. There is no inclusive form.

### 6.2 Conversions and casts

1. `T(x)` and `x as T` are static, total, and differ only in spelling. Both are
   errors in either direction when `T` or `x`'s type is `vector[T, N]`; lane
   conversion is spelled as the constructor instead (§10.4).
2. Legal: numeric to numeric; a unit enum to or from its discriminant type; raw
   pointer to raw pointer; raw pointer to or from a word-width unsigned integer.
3. An abstract handle converts to a raw pointer only when the handle came from a
   **memory-flat** import — every import under `linux`, `windows`, `wasm`, and
   non-framework `darwin`. Handles from **object-graph** imports — JavaScript
   and every Darwin framework — have no byte representation; converting one is
   an error.
4. There is no conversion from a raw pointer to an abstract handle, in any
   spelling. Abstract handles are minted at the foreign boundary only.
5. Float to integer truncates toward zero and traps when out of range.
   Lane-wise float-to-integer conversion (§10.4) follows the same rule, trapping
   when any lane is out of range.
6. Every other conversion is an error. No dynamic cast exists.

### 6.3 Indexing and slicing

1. `a[i]` requires a fixed array, dynamic array, map, or `vector[T, N]`. The
   index must be an integer for arrays and vectors, or assignable to the key
   type for maps.
2. A constant index provably outside a fixed array, or outside a vector's lane
   range, is an error. A runtime index on an array is bounds-checked at runtime;
   a runtime index on a vector is an error outright (§10.6).
3. `a[i..j]` requires an array and yields a slice view. Slicing a map, string,
   or vector is an error.
4. Raw pointers index through their read and write methods only; bracket
   indexing on one is an error.
5. `Ident[T]` is a generic instantiation when `Ident` names a generic
   declaration, and an index otherwise.
6. Subscripting a tensor is an error in every form.

### 6.4 Calls

1. Argument count must match. A variadic parameter absorbs zero or more trailing
   arguments, each assignable to the element type.
2. Arguments may be positional or named; mixing is legal only with every
   positional argument preceding every named one.
3. A named argument must name a declared parameter, and no parameter twice.
4. Arguments evaluate left to right.
5. A marked function called without its launch form, or a launch form applied to
   an unmarked function, is an error in both directions.

### 6.5 Fields and methods

1. `x.f` requires `f` declared on `x`'s own type. There is no inheritance, no
   embedding, no resolution order.
2. Calling a `mut`-receiver method requires the receiver expression to be
   addressable and mutable.
3. Calling a `var`-receiver method transfers the receiver.
4. `x.0` and `x.1` require a tuple of that arity; named tuple fields are reached
   by name.
5. An abstract handle has no fields and no methods; everything callable on one
   is declared for it at the boundary.

### 6.6 Address-of and dereference

Both spell as `&`; direction is read from the operand's type.

1. `&x` where `x` is a raw pointer **dereferences**. Otherwise it takes the
   address.
2. Direction keys on the **statically written** type, so a source line never
   changes meaning between instantiations. Inside a generic body, `&x` where `x`
   has a type-parameter type is always address-of, including when that parameter
   is instantiated as a pointer.
3. `addr(p)` yields the address of a pointer binding itself. It requires a raw
   pointer operand and an addressable one; on any other type it is an error.
4. `&e = v` requires `e` to be a raw pointer and `v` assignable to its pointee.

### 6.7 `nil`

`nil` is admissible in exactly two positions: as a raw pointer value, and as the
right-hand side of a map index assignment, where it erases the entry.

Everywhere else it is an error — including comparing any non-pointer against it,
and ordering any pointer against it.

### 6.8 Closures

1. Captures are by value, fixed at closure creation.
2. Assigning to a captured binding inside the body is an error.
3. Writeback is spelled as a `mut` parameter, never as a capture.
4. A closure that captures nothing and one that captures something share a type
   spelling but not a representation; only the non-capturing form crosses a
   foreign boundary (§12.6).

---

## 7. Functions

### 7.1 Declarations

1. Parameter names are unique; `_` is permitted.
2. A variadic parameter must be last, and there may be at most one.
3. A function with a return type must return on every path.
4. Returning values from a void function, or returning bare from a
   value-returning one, is an error.
5. Return arity must match the declared arity exactly.

### 7.2 Receivers, `init`, `deinit`

1. A receiver type must be declared in the same package.
2. `init` and `deinit` are declarable on classes only.
3. At most one `deinit` per class; it takes no parameters and returns nothing.
4. A class may declare several initializers distinguished by name. The unnamed
   one backs bare construction; a named one backs qualified construction.
5. An `init` must leave every field definitely assigned on every path.
6. A `deinit` may not transfer the receiver or any of its fields.
7. A receiver may be plain, `mut`, `var`, or `shared`. `unique` or `weak` is an
   error.

### 7.3 Markers and coloring

| Marker | Call form | Body |
| --- | --- | --- |
| `async` | `await f()`, or `async f()` to spawn | may contain `await` |
| `gpu` | `gpu f()`, optionally with a launch config | unrestricted |
| `npu` | `npu f()` | restricted, §11.2 |
| `test` | not callable | §13 |

1. A function carries at most one marker.
2. The marker must agree at both ends, in both directions.
3. `await` is legal only inside an `async` body, or in `main`.
4. `await f()` yields the value. `async f()` spawns and yields a receive
   channel; awaiting that channel yields the value later.
5. `thread` is a call prefix and never a marker. The callee's declaration is
   unaffected by any call site that spawns it.
6. A launch keyword immediately followed by `.` is a namespace reference.
7. A blocking call inside an `async` body is a lint, not an error.
8. A launch config, where present, must supply both a block count and a thread
   count.

---

## 8. Generics

1. Type parameter names are unique within a list; `_` is permitted. A
   parameter's scope begins after its own name, so a later parameter may be
   constrained in terms of an earlier one.
2. A bare parameter is constrained by `any`.
3. Two constraints are predeclared: `any` and `comparable`.
4. **A method may not declare its own type parameters.** A receiver re-declares
   the receiver type's list to bring those names into scope; introducing a new
   one is an error.
5. Constraint satisfaction is checked once per instantiation, at the
   instantiation site. In a type set, `~T` admits every type whose underlying
   type is `T`; a bare `T` admits only `T`.
6. **The operations available on a type-parameter value are exactly those its
   constraint grants.** Under `any`: assignment, argument passing, and the
   ownership operations. Equality requires `comparable`; ordering requires an
   ordered type set; arithmetic a numeric one. Everything else is an error,
   reported against the declaration, not the instantiation.
7. Inference applies when every parameter is fixed by a value argument, reaching
   through composite arguments. A parameter appearing only in the return type
   must be supplied explicitly. Inference either succeeds or fails; the compiler
   never partially infers.
8. A constraint in value position is an error.
9. `~T` outside a type set is an error.
10. Instantiation must terminate. A cycle whose type arguments grow without
    bound is an error, detected by depth limit.
11. A generic declaration is fully checked even if never instantiated — its body
    is checked against the constraint, not against any concrete type.

---

## 9. Aggregates and Enums

1. Field names are unique within a declaration.
2. A field may not have the enclosing type directly; an indirection through
   `unique`, `shared`, `weak`, a dynamic array, or a raw pointer breaks the
   cycle. A `vector[T, N]` field is legal without indirection.
3. A composite literal names its fields. Positional struct literals do not
   exist. Omitted fields take their zero value; omitting a field whose type has
   no zero value is an error.
4. A class differs from a struct in its member model only — never in storage,
   assignability, or copying.
5. Enum variant names are unique within the enum. Explicit discriminants must be
   constant, distinct, and representable in the declared discriminant type;
   omitted ones continue from the previous.
6. A payload-carrying enum may not declare a discriminant type.
7. Converting an enum to an integer is legal for unit-only enums.
8. Leading-dot variant shorthand is legal only where the enum type is fixed by
   context: an annotation, a parameter type, or a switch subject.
9. A `switch` over an enum with no `default` must cover every variant.

---

## 10. Vectors

`vector[T, N]` is one CPU SIMD register — a distinct storage class from `[]T`
and `tensor[T, S...]`. No value crosses between the three implicitly.

### 10.1 Well-formedness

1. `T` must be a scalar numeric type: `int8`–`int64`, `uint8`–`uint64`,
   `float32`, `float64`. Everything else is an error.
2. `N` must be an integer literal from `{2, 4, 8, 16, 32, 64}`. A non-literal
   constant expression is an error.
3. `byte` and `uint8` remain interchangeable (§2.1.3), so `vector[byte, 16]` and
   `vector[uint8, 16]` are the same type.
4. Two vector types are identical iff `T` and `N` are both identical.

### 10.2 Zero value

`N` zero lanes. `var v: vector[float32, 8]` with no initializer is legal and
definitely assigned to that value.

### 10.3 Where vectors are illegal

1. Inside a `gpu` or `npu` body, or in either marker's signature.
2. As a parameter or result crossing a foreign boundary (§12.5.1).
3. As a `map` key type — vector equality yields a lane predicate, not `bool`, so
   `comparable` is not satisfied.

Vectors are legal as struct and class fields, as array elements, as channel
element types, and under `unique`, `shared`, or `weak`.

### 10.4 Construction

`VectorType(...)` is a compiler intrinsic with three signatures, disambiguated
by argument shape:

1. **Splat** — one argument assignable to `T`, need not be constant. Every lane
   takes that value.
2. **Load** — two arguments: a slice or array whose element type is identical to
   `T` (not merely convertible), and an integer index. Reads `N` consecutive
   elements from there. Bounds-checked by comparing `i + N` against the source's
   length, trapping on failure — unless the index is a constant provably out of
   range on a fixed array, which is a compile-time error and emits no check. The
   first argument is a shared borrow for the call's duration.
3. **Lane conversion** — one argument of type `vector[T2, N]`, same `N`, `T2` a
   scalar numeric type not identical to `T`. Each lane converts:
   float-to-integer truncates toward zero and traps on any lane out of range;
   integer-to-float and integer-to-integer do not trap. Changing `N` is not
   supported.

`copy` is additionally overloaded as the vector store: when its destination is a
slice view of constant length `N` and its source is a `vector[T, N]`, the
lengths must match exactly (a view of any other constant length, or of runtime
length, is an error), the viewed buffer must be reachable through a `mut` or
`var` binding, and the destination view holds a `mut` borrow for the call
(§5.4.5).

### 10.5 Operations and the lane predicate

Operands of a vector operation must match exactly in both `T` and `N`. There is
no broadcasting; a scalar operand alongside a vector operand is an error, and
splat construction is the explicit form for that case.

`==`, `!=`, `<`, `<=`, `>`, `>=` on two identical vector types yield a **lane
predicate**: a value carrying `(T, N)` — `N` boolean lanes at `T`'s lane width.
This is the only exception to §6.1's "yields `bool`" rule.

The lane predicate has no source spelling: no type name, no `TypeName`
production, no `PredeclaredTypeName` entry. It is produced only by a vector
comparison, and consumed only by `blend` (§10.7) and by `&`, `|`, `^`, `~` on
two predicates of identical `(T, N)`, which yield a predicate. `min`, `max`, and
`clamp` do not consume it.

1. A lane predicate is not a `bool`. It is an error as the condition of an `if`
   or `while`, as a `switch` subject, and as an operand of `&&`, `||`, or `!`.
2. It has no field, array element, channel element, global, parameter, or return
   position — it cannot be named in a signature.
3. It never crosses a foreign boundary.
4. It has no indexing form, no method, and no field access.

### 10.6 Extraction

`v[k]` yields lane `k` as a `T`, legal only when `k` is a constant expression in
range. A runtime index is an error. There is no lane-assignment form: `v[2] = x`
is always an error.

Because `N` is always a literal, `v[0] + v[1] + … + v[N-1]` is legal Vertex, so
horizontal reduction needs no dedicated builtin.

### 10.7 `blend`, `min`, `max`, `clamp`

Four reserved free-function names (§1.8), each a single instruction on every
target:

| Form | Requires | Yields |
| --- | --- | --- |
| `blend(m, a, b)` | `a`, `b` identical `vector[T, N]`; `m`'s carried `(T, N)` identical to theirs | `vector[T, N]`, lane `i` from `a` where `m`'s lane `i` is true, else from `b` |
| `min(a, b)`, `max(a, b)` | `a`, `b` identical `vector[T, N]` | `vector[T, N]`, lane-wise |
| `clamp(v, lo, hi)` | all three identical `vector[T, N]` | `vector[T, N]`, lane-wise |

`blend`'s matching rule is exact: matching `N` alone is insufficient, since a
predicate from a `float32` comparison and a `vector[int8, 8]` destination agree
on lane count but not lane width. None of the four is callable as a method.

### 10.8 Ownership and cost

A vector and a lane predicate are thin values (§5.5.1): copying is a register
move, `var` transfer is legal and identical to a copy in emitted code (the
marker still affects liveness), and neither has a teardown. Neither is
addressable in the sense that forces a stack slot, except by the ordinary
triggers — `mut` passing, `addr`, closure capture, liveness across an `await` —
and a lane predicate can reach none of these (§10.5.2).

---

## 11. Device Code

### 11.1 `gpu`

The body is unrestricted. Arguments and results are ordinary host types, and the
call returns its value directly. `vector[T, N]` is illegal in a `gpu` body or
signature (§10.3.1).

### 11.2 `npu`

1. Tensor types are legal only inside an `npu` body or that function's own
   signature; elsewhere they are an error. `vector[T, N]` is illegal inside an
   `npu` body or signature (§10.3.1).
2. Two element types are signature-eligible: `float32` and `int8`. The reduced
   and quantized types are body-only; one in a signature is an error.
3. Shape entries must be constant integer literals.
4. Subscripting a tensor is an error — element access is through elementwise
   operators and the device namespace only.
5. Elementwise operands must agree exactly in element type and shape. The
   explicit broadcast operation is the only broadcast.
6. An `if` or `switch` selector must be scalar; per-element choice is the select
   operation.
7. In a `while`, every loop-carried binding must keep identical type, shape, and
   element type across iterations. `break` and `continue` are errors.
8. The device namespace is a closed set. Declaring, shadowing, or extending a
   member is an error.

---

## 12. Channels, `select`, and Interop

### 12.1 Channels

1. A channel is constructed with an element type and an optional non-negative
   capacity.
2. Sending is an owning position: the value copies or transfers by the ordinary
   marker rule.
3. A channel element type must have a zero value, since the non-blocking receive
   returns a boundary tuple. A `vector[T, N]` qualifies; a lane predicate cannot
   be named as a channel element type at all (§10.5.2).
4. `.receive()` blocks the calling thread when written bare, and suspends the
   task when written under `await`. The two are distinguished by the `await`,
   never by the channel.

### 12.2 `select`

1. Every case must be a blocking or non-blocking receive on a channel. Any other
   expression in case position is an error.
2. One `select` is entirely bare or entirely awaited. Mixing is an error.
3. Awaited cases are legal only inside an `async` body.
4. At most one `default`, and it makes the whole statement non-blocking.

### 12.3 Declare blocks — placement

1. A `declare` block requires a build tag in its file.
2. `declare framework` is legal only under `darwin`; under any other build tag
   it is an error.
3. `declare framework` never takes a variant tag.
4. A `declare module` containing a class selects a default convention by build
   tag:

   | Build tag | Default |
   | --- | --- |
   | `darwin`, `linux` | C++, Itanium ABI, exceptions on |
   | `windows` | raw C++ vtable call |
   | `js` | ordinary object/class call shape |

5. A variant tag overrides that default and is drawn from a closed set:
   `"windows"`, `"com"`, `"cxx"`, `"no-exceptions"`. An unknown tag, a
   contradictory pair, or one inapplicable to the file's build tag is an error.
6. Omitting the tag selects the default. The bracket narrows an existing default
   and never grants a capability the default lacks.

### 12.4 Declare blocks — contents

A declare block describes call shapes only. Inside one, each of these is an
error: a function or method **body**; a **field** in a foreign class; a
**visibility modifier**; an **ownership qualifier**; a second unnamed
initializer; an initializer returning anything but the enclosing foreign class;
a nested declare block.

### 12.5 Boundary types

1. A parameter or result must be a primitive, a string, an array or mutable
   array, a `mut` scalar out-parameter, a raw pointer, an abstract handle, or a
   tuple of these. `vector[T, N]` is none of these and is an error here
   (§10.3.2).
2. A layout-dependent foreign type crossing directly — a foreign struct by
   value, a template instance — is an error. Wrap it behind an abstract handle
   and expose accessors.
3. The boundary tuple is the shape for a fallible foreign call. It is a
   convention on the Vertex side; nothing verifies it against the foreign
   library.

### 12.6 Callbacks

Only a non-capturing function crosses a boundary. Passing a capturing closure to
a foreign parameter is an error: the foreign slot holds one word, the closure is
two, and nothing foreign will own the environment.

---

## 13. Errors, Panics, Tests

1. The boundary tuple is a **convention**. Nothing forces a fallible function to
   adopt it, and nothing forces a caller to check the string. There is no
   propagation operator.
2. What is enforced: destructure arity, and that the value on a declared error
   path is a well-formed value of its type. That it is the *zero* value is not
   verified.
3. `panic` does not return. Code after it in the same block is unreachable, and
   a `panic` satisfies the requirement that every path return.
4. Test-marked functions are legal only in a file built under the `test` tag.
5. A test's declared expected type must match its return type, and the expected
   string is compared against that type's emitted formatting.
6. An expectation of failure inverts the judgment: the body is expected not to
   compile, and a body that compiles is a **test failure**, not a compile error.
   An expectation carrying a string additionally requires the diagnostic to
   match.

---

## 14. Program

1. Exactly one `main`, in package `main`, taking no parameters. It may contain
   `await` without carrying the `async` marker; it is the reactor root.
2. A file's build tag gates whether its declarations enter the package. An
   excluded file is still parsed and syntax-checked.
3. Import cycles between packages are an error, and so is self-import.
4. An unused import is a lint, not an error.

---

## 15. Ordering the Rules Depend On

Semantic guarantees; the rules above are unsound without them.

1. Arguments evaluate left to right.
2. Fields tear down in reverse declaration order; locals in reverse declaration
   order.
3. `defer` bodies run in reverse registration order, on every exit edge of their
   scope — fall-through, `return`, `break`, and `continue` alike. With no
   unwinder, "every exit edge" is a finite static set.
4. A transferred binding's teardown is not emitted; the obligation moves to the
   destination.

Rule 4 is why §5.3.2 rejects conditional transfer: the moment "was it
transferred?" becomes a runtime question, the language would need a per-binding
flag, so it forbids the question instead.