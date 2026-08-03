## Generics

---

## 0. Import

```vertex
import "builtins/constraints"   // Ordered, Integer, Number, Float, ... (§4)
```

`any` and `comparable` are predeclared — no import needed. The qualifier
`constraints.` comes from that package's own `package` clause, not from the import
path (foundation §30).

Vertex has no interfaces and no runtime type information. A generic is a compile-time
stamping mechanism and nothing else: every instantiation becomes a separate concrete
body (§8), and a constraint is a set of types checked at each instantiation site, not
a value a variable can hold.

**A note on the signatures in this file.** Several examples below show a `func` line
with no body, to put the signature under discussion on one line. Every real
declaration carries a block; the bodyless lines are sketches, not source.

---

## 1. Type Parameter Lists — `[...]`

A type parameter list follows the declared name, in square brackets, before the
value-parameter list, fields, or body. Every declaration form that can be generic
accepts one:

```vertex
func   identity[T](x: T) -> T

struct Pair[A, B] {
    first:  A
    second: B
}

class  Stack[T] { items: []T = [] }

enum   Option[T] { None, Some(T) }

type   Vec[T] = []T
```

* A bare name is constraint `any` — `[T]` means `[T: any]`. This is the form the
  allocation builtins already use (`new[T]`, memory §11.1).
* A constraint is introduced with `:` — `[T: Ordered]`.
* Successive names may share one constraint — `[A, B: Number]` constrains both. The
  distribution is performed over an already-parsed list rather than by the grammar,
  so a formatter can reproduce what was written.
* Names must be unique; the blank name `_` is allowed for an unused parameter.
* **Scope.** A type parameter's name is in scope across the *entire* list and the
  whole declaration that follows it. Order within the list does not matter, so a
  parameter may be constrained by one declared after it: `[S: ~[]E, E]` is
  well-formed.

```vertex
func pairOf[A, B](a: A, b: B) -> Pair[A, B]
func lookup[K: comparable, V](m: map[K]V, k: K) -> (V, string)
```

Two declaration forms notably do **not** take a parameter list:

* **A `MethodDecl`** may not declare its own (§9). Everything a method is generic
  over comes from its receiver.
* **A `ConstraintDecl`** has no `TypeParameters` slot at all — there is no
  `constraint Container[T] { … }`. A constraint is a flat type set plus method
  requirements, never parameterized.

`Option` above is an ordinary user enum. The language has no built-in `Option` and
no built-in `Result`: fallibility is the boundary tuple of foundation §35, and
absence goes through the same channel (foundation §35.4).

---

## 2. Using a Type Parameter

Inside the declaration, a type parameter is an ordinary type name — legal in fields,
value-parameter types, return types, locals, and nested type arguments:

```vertex
func first[T](items: []T) -> (T, string) {
    if items.length == 0 {
        var zero: T
        return zero, "empty"          // §6 — zero value on the error path
    }
    return items[0], ""
}
```

The operations permitted on a value of type `T` are exactly those permitted by `T`'s
constraint (§3). Under `any`, only assignment, argument passing, and the ownership
operations (§7) are available — no `<`, no `+`, no `==`, no field access.

This is checked against the *constraint*, not against the types that happen to be
substituted. A body that uses `<` under `any` is an error even if every instantiation
in the program supplies an ordered type: the declaration is checked once, on its own
terms, and only constraint satisfaction is checked per instantiation (§8).

---

## 3. Constraints — `constraint`

Vertex has no interfaces, so a constraint is its own declaration: a compile-time
**type set**, optionally paired with required methods. A constraint is never a value
type — it exists only in a `[...]` position.

### 3.1 Type-Set Constraints

```vertex
constraint Small {
    ~int8 | ~int16 | ~int32
}
```

* `|` is a **union** — the type set is every listed type.
* `~T` admits `T` and every type whose underlying type is `T` (so a
  `type Celsius = float32` alias still satisfies `~float32`). A bare `T` (no tilde)
  admits only `T` exactly.
* `~` here is underlying-type, not bitwise-NOT (foundation §9). The two never
  collide: `~` is underlying-type only inside a type-set element, exactly as `&` is
  address-of vs. dereference by operand position (memory §2). Outside a type set, a
  `~` before a type is an error.

**One element per line.** A constraint body is newline-separated: each line is one
`ConstraintElem`, and the line terminator ends it. A single type set must therefore
be written on one line — a union broken across lines with a trailing `|` is not a
continuation, it is two elements, which §3.3 reads as an *intersection*. Build long
sets by embedding instead (§3.3, §4):

```vertex
constraint Numericish {
    constraints.Number     // embed — one line, one element
}
```

### 3.2 Method Constraints

```vertex
constraint Stringer {
    func toString() -> string
}
```

Any type declaring a matching receiver method (`func (x: T) toString() -> string`)
satisfies `Stringer`. Because Vertex monomorphizes (§8), the call inside the generic
body lowers to a direct call on the concrete type — there is no dynamic dispatch, and
this is **not** an interface value.

A `MethodRequirement` takes a full `Signature`, so a marker is part of what is
required:

```vertex
constraint Reader {
    func read(buf: mut []byte) async -> (int32, string)
}
```

A type satisfies `Reader` only with a method carrying the `async` marker, since the
marker is part of a function's type (foundation §31).

### 3.3 Intersection & Embedding

Multiple elements in a constraint body are an **intersection** — a type argument must
satisfy all of them. A bare constraint name embeds that constraint's set:

```vertex
constraint SortKey {
    constraints.Ordered     // embed: must be in Ordered's type set
    func weight() -> int64  // AND declare this method
}
```

A name in a type-set position resolves by what it denotes: a type contributes itself,
a constraint contributes its whole set. That holds inside a union as well as alone,
which is what lets §4's library build one set out of others:

```vertex
constraint Integerish {
    constraints.Signed | constraints.Unsigned    // union of two sets
}
```

The two shapes are worth keeping straight: `A | B` on one line is the union of two
sets, while `A` and `B` on separate lines is their intersection.

### 3.4 Predeclared Constraints

| Constraint | Admits |
| --- | --- |
| `any` | every type (the default when `:` is omitted) |
| `comparable` | every type supporting `==` / `!=` |

`comparable` is what a `map[K]V` key parameter or a set needs; under `any`, `==` on a
`T` is a compile error. Both are ordinary identifiers pre-bound in an implicit
outermost scope, legal only in a `[...]` position and never as a `Type`.

`vector[T, N]` is the notable type *outside* `comparable`: a lane-wise `==` on two
vectors yields a lane predicate rather than a `bool`, which is why a vector cannot be
a map key (accel §3.4).

### 3.5 Inline Constraints

A constraint may be written inline in the list, without a named declaration — useful
for one-off shapes:

```vertex
func keys[K: comparable, V](m: map[K]V) -> []K
func concat[S: ~[]E, E](a: S, b: S) -> S
func limit[T: ~int32 | ~float64](v: T, lo: T, hi: T) -> T
```

`concat` is the case §1's scope rule exists for: `S` is constrained by `~[]E` using
`E`, which is declared after it.

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

Every row uses `~`, so a named alias of a numeric type satisfies them. The last four
rows are unions of constraint names, per §3.3.

`byte` needs no row of its own: it is an alias for `uint8`, not a distinct type
(foundation §4.1), so `~uint8` already admits it.

```vertex
func smaller[T: constraints.Ordered](a: T, b: T) -> T {
    if a < b {
        return a
    }
    return b
}
```

> The example is named `smaller`, not `min`. `min`, `max`, `clamp`, and `blend` are
> reserved builtin names (grammar.md, *Reserved builtin names*; they are the
> lane-wise free functions of accel §3.3) and may not be redeclared, generically or
> otherwise.

---

## 5. Instantiation

An instantiation supplies type arguments in `[...]` after the name; the compiler
substitutes them, then checks each against its constraint.

### 5.1 Explicit

```vertex
class Stack[T] {
    items: []T = []
}

func (s: Stack[T]) init() {
}
```

```vertex
let s = Stack[int32]()
let p = Pair[int32, string]{ first: 1, second: "a" }
let m = smaller[float64](3.14, 2.71)

let buf, err = new[uint8](1024)          // builtin generic, memory §11.1
```

The three construction spellings differ by what is being constructed, not by
genericity: `Stack` is a class and is constructed by calling an initializer, `Pair`
is a struct and takes a composite literal, and `smaller` is a function call
(foundation §27). A generic class needs a declared `init` exactly as a non-generic
one does — `Stack[int32]{}` constructs nothing.

### 5.2 Inferred from Arguments

When every type parameter is determined by a value argument, the `[...]` may be
dropped — matching `delete(buf)` (memory §11.2), which infers `T` from `p`:

```vertex
let x = smaller(3, 5)                    // T = int32, inferred
let y = smaller(3.14, 2.71)              // T = float64, inferred

delete(buf)                              // T inferred from buf
```

Inference reaches through composite arguments — a `[]T` argument fixes `T`, a `~[]E`
constraint fixes `E`. Inference either succeeds or fails; on failure the compiler
asks for explicit arguments rather than guessing.

### 5.3 When Explicit Is Required

A type parameter that appears only in the return type (or nowhere in the value
parameters) cannot be inferred and must be supplied:

```vertex
func zeroOf[T]() -> T {
    var z: T
    return z
}

let n = zeroOf[int32]()                  // ok
let m = zeroOf()                         // error: cannot infer `T`
```

**`new` and `resize` are a stated exception to this rule.** Their `T` appears only in
the return type, yet `buf, err = new(1024)` infers it from the destination's declared
pointer type (memory §11.1). The exception is scoped to those two builtins and only
where the destination type is already written down; no user-declared generic gets
destination-driven inference.

### 5.4 Instantiation vs. Indexing

`Stack[int32]` (instantiation) and `a[i]` (index) share bracket syntax; they are
distinguished by whether the operand names a generic declaration. Resolution is by
what the operand denotes, not by the shape of what is inside the brackets — this is
the one syntactic overlap the parser resolves by meaning.

---

## 6. Zero Value of a Type Parameter

`var z: T` yields `T`'s zero value — `0`, `""`, `false`, a zeroed struct, a zeroed
class, or `nil` for `typed_ptr T` (memory §13). This is the value handed back on the
error path of a generic fallible function, exactly matching the boundary-tuple
zero-value rule (foundation §35.5):

```vertex
func get[T](items: []T, i: int32) -> (T, string) {
    if i < 0 || i >= items.length {
        var zero: T
        return zero, "out of range"
    }
    return items[i], ""
}
```

There is no general `nil` for a `T` (foundation §35) — absence is the tuple, and the
zero value fills the value slot. `var z: T` is also the only way to name a `T` a
generic body has not been handed: under `any` there is no constructor to call and no
literal that means "a `T`."

The declaration form is the initializer-free `var` (foundation §3); a `let` always
takes an initializer, so `let z: T` is not available here.

---

## 7. Generics and Ownership

The three conventions (ownership §4) apply to a `T` unchanged — the convention is
fixed in the signature, the copy/transfer choice is made at the call site with the
`var` marker:

```vertex
func store[T](x: var T)       // owning  — call site picks transfer or copy
func mutate[T](x: mut T)      // exclusive
func read[T](x: T)            // shared
```

```vertex
var w = Widget(1)

store(var w)                  // TRANSFER — O(1), `w` dead afterwards
store(w)                      // COPY (bare) — cost depends on concrete T
```

There is no method form of transfer. `var` at the call site is the entire difference
between a move and a deep copy, in a generic body exactly as everywhere else
(ownership §3).

The **cost** of a bare copy is decided by the concrete type substituted at
instantiation (ownership §11): a thin `T` copies by register move, a fat `T`
(`string`, `[]U`) deep-copies its payload. A generic body cannot see which — so a
lint on large owned types fires per instantiation, not per declaration.

`var` takes a binding or a field path, never a computed expression — the rule does
not relax inside a generic:

```vertex
store(var w)                  // ok — binding
store(var self.cache.slot)    // ok — field path
store(var pick(a, b))         // error: transfer requires a binding
                              //        or field path (ownership §3)
```

`shared T`, `unique T`, and `weak T` may all be type arguments, and a type parameter
may itself be wrapped: `unique(Stack[int32]())`.

`typed_ptr T` is the one type argument the ownership rules do not reach. Substituting
it does not make the body unsafe by itself, but nothing in `ownership.md` governs the
result: two copies are two unchecked aliases, and no teardown is emitted (memory §1).

---

## 8. Lowering — Monomorphization

Every instantiation is compiled as a separate concrete body with the type arguments
substituted in. Vertex carries no runtime type information, no dictionaries, and no
dispatch table — so a generic that survives to the binary must have been stamped out
per concrete type at compile time.

Consequences:

* A generic declaration that is **never instantiated** emits no code at all.
* Constraint satisfaction is checked once **per instantiation**; an unsatisfied
  constraint is a compile error at the instantiation site, not a runtime failure.
* A method-constraint call (§3.2) lowers to a direct call on the concrete type — the
  same machine shape as any other direct call. No vtable is introduced.
* Recursive instantiation must terminate — `Node[Node[T]]` deepening without bound is
  a compile error (the stamping would not terminate).

The declaration itself is still checked once, independently of any instantiation
(§2). Monomorphization decides what is *emitted*, not what is *legal*.

---

## 9. Methods on Generic Types

A method receiver re-declares the type's parameter list to bring the names into
scope; the method body then uses them like any type:

```vertex
class Stack[T] {
    items: []T = []
}

func (s: Stack[T]) init() {
}

func (s: mut Stack[T]) push(item: var T) {
    s.items.push(var item)
}

func (s: mut Stack[T]) pop() -> (T, string) {
    if s.items.length == 0 {
        var zero: T
        return zero, "empty"
    }
    let item, err = s.items.pop()
    return item, err
}
```

* `push` declares `item` owning (`var T`), and moves it onward with `var item` at the
  inner call site. A bare `s.items.push(item)` there would deep-copy the payload of a
  fat `T` — see §7.
* `pop` destructures the inner call before returning. `[]T`'s own `pop` returns a
  boundary tuple (foundation §22.3), and a bare comma return unbuilds values into the
  result slots — `return s.items.pop(), ""` would be handing back a tuple *and* a
  string into a two-slot result, which does not typecheck.
* The receiver's `[T]` **binds** the name — the list re-declares the receiver type's
  existing parameters rather than introducing fresh ones.
* A method may **not** introduce a type parameter of its own, on a generic receiver
  or a non-generic one. The grammar parses the slot anyway so the diagnostic can
  point a caret at it (§10).
* A constraint declared on the type (`class Stack[T: Ordered]`) is in force inside
  every method — the method may use `<` on a `T` because the type guaranteed it. The
  receiver's own list does not restate the constraint.

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

func f(x: any)              // error: `any` is a predeclared constraint name and
                            //        is not a Type either

type X = ~int               // error: `~int` is only valid inside a type set (§3.1)

func dup[T, T](x: T)        // error: duplicate type parameter name `T`

constraint Box[T] {         // error: a constraint takes no type parameters (§1)
    ~[]T
}

func onlyReturn[T]() -> T   // (declaration ok)
let v = onlyReturn()        // error: cannot infer `T` — supply onlyReturn[...]()

class Box[T] { v: T }
func (b: Box[T]) convert[U](f: func(T) -> U) -> Box[U]
//                     ^^^ error: a method may not declare its own type
//                         parameter `U`; only the receiver's parameters
//                         are in scope (§9)

func f[T: int | int32](x: T)
let r = f[MyInt](...)       // error: `MyInt` (underlying int) not in `int | int32`
                            //        — add `~` (`~int | ~int32`) to admit it

func min[T: constraints.Ordered](a: T, b: T) -> T
                            // error: `min` is a reserved builtin name and may
                            //        not be declared (§4)

func store[T](x: var T)
store(w.transfer())         // error: there is no `.transfer()` method —
                            //        transfer is the `var` call-site marker,
                            //        `store(var w)` (§7, ownership §3)

constraint Wide {
    ~int8 |
    ~int16                  // error: the line terminator ends the first
}                           //        element — this is an intersection of two
                            //        type sets, not one union (§3.1)
```