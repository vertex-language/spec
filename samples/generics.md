## Generics

---

## 0. Import

```vertex
import "builtins/constraints"   // Ordered, Integer, Number, Float, ... (§4)
```

`any` and `comparable` are predeclared — no import needed.

---

## 1. Type Parameter Lists — `[...]`

A type parameter list follows the declared name, in square brackets, before the
value-parameter list, fields, or body. Every declaration form accepts one:

```vertex
func   identity[T](x: T) -> T
struct Pair[A, B] { first: A  second: B }
class  Stack[T] { items: []T }
enum   Option[T] { None, Some(T) }
type   Vec[T] = []T
```

* A bare name is constraint `any` — `[T]` means `[T: any]` (this is the form
  already used by `memory.Alloc[T]`, memory §12).
* A constraint is introduced with `:` — `[T: Ordered]`.
* Successive names may share one constraint — `[A, B: Number]` constrains both.
* Names must be unique; the blank name `_` is allowed for an unused parameter.
* The scope of a type parameter begins after its own name and runs to the end of
  the declaration's body — so a later parameter may be constrained by an earlier
  one: `[S: ~[]E, E]`.

```vertex
func pairOf[A, B](a: A, b: B) -> Pair[A, B]
func lookup[K: comparable, V](m: map[K]V, k: K) -> (V, string)
```

---

## 2. Using a Type Parameter

Inside the declaration, a type parameter is an ordinary type name — legal in
fields, value-parameter types, return types, locals, and nested type arguments:

```vertex
func first[T](items: []T) -> (T, string) {
    if items.length == 0 {
        var zero: T
        return zero, "empty"          // §6 — zero value on the error path
    }
    return items[0], ""
}
```

The operations permitted on a value of type `T` are exactly those permitted by
`T`'s constraint (§3). Under `any`, only assignment, argument passing, and the
ownership operations (§7) are available — no `<`, no `+`, no field access.

---

## 3. Constraints — `constraint`

Vertex has no interfaces, so a constraint is its own declaration: a compile-time
**type set**, optionally paired with required methods. A constraint is never a
value type — it exists only in a `[...]` position.

### 3.1 Type-Set Constraints

```vertex
constraint Ordered {
    ~int | ~int8 | ~int16 | ~int32 | ~int64 |
    ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 |
    ~float32 | ~float64 | ~string
}
```

* `|` is a **union** — the type set is every listed type.
* `~T` admits `T` and every type whose underlying type is `T` (so a
  `type Celsius = float32` alias still satisfies `~float32`). A bare `T` (no
  tilde) admits only `T` exactly.
* `~` here is underlying-type, not bitwise-NOT (foundation §9). The two never
  collide: `~` is underlying-type only inside a type-set element, exactly as `&`
  is address-of vs. dereference by operand position (memory §2).

### 3.2 Method Constraints

```vertex
constraint Stringer {
    func toString() -> string
}
```

Any type declaring a matching receiver method (`func (x: T) toString() -> string`)
satisfies `Stringer`. Because Vertex monomorphizes (§8), the call inside the
generic body lowers to a direct call on the concrete type — there is no dynamic
dispatch, and this is **not** an interface value.

### 3.3 Intersection & Embedding

Multiple elements in a constraint body are an **intersection** — a type argument
must satisfy all of them. A bare constraint name embeds that constraint's set:

```vertex
constraint SortKey {
    Ordered                 // embed: must be in Ordered's type set
    func weight() -> int64  // AND declare this method
}
```

### 3.4 Predeclared Constraints

| Constraint | Admits |
| --- | --- |
| `any` | every type (the default when `:` is omitted) |
| `comparable` | every type supporting `==` / `!=` |

`comparable` is what a `map[K]V` key parameter or a set needs; under `any`, `==`
on a `T` is a compile error.

### 3.5 Inline Constraints

A constraint may be written inline in the list, without a named declaration —
useful for one-off shapes:

```vertex
func keys[K: comparable, V](m: map[K]V) -> []K
func concat[S: ~[]E, E](a: S, b: S) -> S
func clamp[T: ~int32 | ~float64](v: T, lo: T, hi: T) -> T
```

---

## 4. The Standard Constraint Library

```vertex
import "builtins/constraints"
```

| Name | Type set |
| --- | --- |
| `constraints.Signed` | `~int \| ~int8 \| ~int16 \| ~int32 \| ~int64` |
| `constraints.Unsigned` | `~uint \| ~uint8 \| ~uint16 \| ~uint32 \| ~uint64` |
| `constraints.Integer` | `Signed \| Unsigned` |
| `constraints.Float` | `~float32 \| ~float64` |
| `constraints.Number` | `Integer \| Float` |
| `constraints.Ordered` | `Number \| ~string` |

```vertex
func min[T: constraints.Ordered](a: T, b: T) -> T {
    if a < b { return a }
    return b
}
```

---

## 5. Instantiation

An instantiation supplies type arguments in `[...]` after the name; the compiler
substitutes them, then checks each against its constraint.

### 5.1 Explicit

```vertex
let s   = Stack[int32]()                 // class construction
let p   = Pair[int32, string]{ first: 1, second: "a" }
let buf, err = memory.Alloc[uint8](1024) // as in memory §12
let m   = min[float64](3.14, 2.71)
```

### 5.2 Inferred from Arguments

When every type parameter is determined by a value argument, the `[...]` may be
dropped (matching `memory.Free(buf)`, memory §12.2, which infers `T` from `p`):

```vertex
let x = min(3, 5)                        // T = int32, inferred
let y = min(3.14, 2.71)                  // T = float64, inferred
memory.Free(buf)                         // T inferred from buf
```

Inference reaches through composite arguments — a `[]T` argument fixes `T`, a
`~[]E` constraint fixes `E`. Inference either succeeds or fails; on failure the
compiler asks for explicit arguments rather than guessing.

### 5.3 When Explicit Is Required

A type parameter that appears only in the return type (or nowhere in the value
parameters) cannot be inferred and must be supplied:

```vertex
func zeroOf[T]() -> T { var z: T  return z }

let n = zeroOf[int32]()                  // ok
let m = zeroOf()                         // error: cannot infer `T`
```

### 5.4 Instantiation vs. Indexing

`Stack[int32]` (instantiation) and `a[i]` (index) share bracket syntax; they are
distinguished by whether the operand names a generic type or function. This is
the one syntactic overlap the parser resolves by the operand's meaning.

---

## 6. Zero Value of a Type Parameter

`var z: T` yields `T`'s zero value — `0`, `""`, `false`, a zeroed struct/class,
or `nil` for `typed_ptr T`. This is the value handed back on the error path of a
generic fallible function, exactly matching the boundary-tuple zero-value rule
(foundation §35.5):

```vertex
func get[T](items: []T, i: int32) -> (T, string) {
    if i < 0 || i >= items.length {
        var zero: T
        return zero, "out of range"
    }
    return items[i], ""
}
```

There is no general `nil` for a `T` (foundation §6) — absence is the tuple, and
the zero value fills the value slot.

---

## 7. Generics and Ownership

The three conventions (ownership §3) apply to a `T` unchanged — the convention is
fixed in the signature, the copy/transfer choice is made at the call site:

```vertex
func store[T](x: var T)       // owning — caller writes .transfer() or copies
func mutate[T](x: mut T)      // exclusive
func read[T](x: T)            // shared
```

```vertex
var w = Widget(1)
store(w.transfer())           // TRANSFER
store(w)                      // COPY (bare) — cost depends on concrete T
```

The **cost** of a bare copy is decided by the concrete type substituted at
instantiation (foundation §3): thin `T` copies by register move, a fat `T`
(`string`, `[]U`) deep-copies its payload. A generic body cannot see which — the
§6.4/§10 lint on large owned types applies per instantiation.

`shared T`, `unique T`, and `weak T` may all be type arguments, and a type
parameter may itself be wrapped: `unique(Stack[int32]())`.

---

## 8. Lowering — Monomorphization

Every instantiation is compiled as a separate concrete body with the type
arguments substituted in. This follows directly from foundation §14: there is no
runtime type information, no dictionaries, and no dispatch table to carry a
generic through the runtime — so a generic that survives to the binary must have
been stamped out per concrete type at compile time.

Consequences:
* A generic declaration that is **never instantiated** emits no code at all.
* Constraint satisfaction is checked once **per instantiation**; an unsatisfied
  constraint is a compile error at the instantiation site, not a runtime failure.
* A method-constraint call (§3.2) lowers to a direct call on the concrete type —
  same machine shape as any other direct call (foundation §3.2). No vtable is
  introduced.
* Recursive instantiation must terminate — `Node[Node[T]]` deepening without
  bound is a compile error (the stamping would not terminate).

---

## 9. Methods on Generic Types

A method receiver re-declares the type's parameter list to bring the names into
scope; the method body then uses them like any type:

```vertex
class Stack[T] { items: []T }

func (s: mut Stack[T]) push(item: var T) {
    s.items.push(item.transfer())
}

func (s: mut Stack[T]) pop() -> (T, string) {
    if s.items.length == 0 {
        var zero: T
        return zero, "empty"
    }
    return s.items.pop(), ""
}
```

* The receiver's `[T]` **binds** the name — a method may **not** introduce a new
  type parameter of its own. Everything the method is generic over comes from the
  receiver type.
* A constraint declared on the type (`class Stack[T: Ordered]`) is in force inside
  every method — the method may use `<` on a `T` because the type guaranteed it.

---

## 10. Illegal Forms

```vertex
func bad[T](a: T, b: T) -> bool {
    return a < b            // error: `<` not permitted — `T`'s constraint is
}                           //        `any`; constrain with Ordered to allow it

func badEq[T](a: T, b: T) -> bool {
    return a == b           // error: `==` requires `comparable`, not `any`
}

var c: Ordered              // error: `Ordered` is a constraint, not a type —
                            //        legal only in a `[...]` position

type X = ~int               // error: `~int` is only valid inside a type set (§3.1)

func dup[T, T](x: T)        // error: duplicate type parameter name `T`

func onlyReturn[T]() -> T   // (declaration ok)
let v = onlyReturn()        // error: cannot infer `T` — supply onlyReturn[...]()

class Box[T] { v: T }
func (b: Box[T]) map[U](f: func(T) -> U) -> Box[U]
//              ^^^ error: a method may not declare its own type parameter `U`;
//                  only the receiver's parameters are in scope (§9)

func f[T: int | int32](x: T)
let r = f[MyInt](...)       // error: `MyInt` (underlying int) not in `int | int32`
                            //        — add `~` (`~int | ~int32`) to admit it
```