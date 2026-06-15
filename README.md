# Vertex Language Grammar

## Specification 2.2

---

## 1. Literals

```vertex
// Integers — decimal (default)
42
-1000
1_000_000       // underscore separator — ignored by compiler

// Integers — alternate bases
0b101010        // binary   (base 2)
0o52            // octal    (base 8)
0x2A            // hex      (base 16)

// Hex digits are case-insensitive
0xFF
0xBadFace
0x0123_4567_89ab_cdef   // underscores valid in any base

// float32s — decimal
3.14
1_000.000_1
1.25e2          // = 1.25 × 10²  = 125.0
1.25e-2         // = 1.25 × 10⁻² = 0.0125
1.25E2          // uppercase E — equivalent

// float32s — hex (binary exponent)
0xFp2           // = 15 × 2²  = 60.0
0xFp-2          // = 15 × 2⁻² = 3.75
0xC.3p0         // fractional hex mantissa

// Boolean
true
false

// Nil — absence of a value
nil

// Other literals
"hello"
"A"
```

---

## 2. Variable Declarations

```vertex
let x = 10
var y = 20
```

---

## 3. Type Annotations

```vertex
let a: int    = 100
let b: int8   = 127
let c: int16  = 32767
let d: int32  = 2147483647
let e: int64  = 9223372036854775807
let f: uint   = 100
let g: uint8  = 255
let h: uint16 = 65535
let i: uint32 = 4294967295
let j: uint64 = 18446744073709551615
let k: float32  = 3.14
let l: float64 = 3.14159265358979
let m: bool   = true
let n: string = "hello"
let o: string = `
multi
line
`
let p: char = 'A'
let q: void = ()
```

Multiline strings are delimited by backticks. Content begins after the opening
backtick and ends before the closing backtick. No indentation stripping is applied.

**Scalar type table:**

| Vertex type       | C type     | Notes                  |
|-------------------|------------|------------------------|
| `int` / `int32`   | `int32_t`  | default integer        |
| `int8`            | `int8_t`   |                        |
| `int16`           | `int16_t`  |                        |
| `int64`           | `int64_t`  |                        |
| `uint` / `uint32` | `uint32_t` | default unsigned       |
| `uint8`           | `uint8_t`  |                        |
| `uint16`          | `uint16_t` |                        |
| `uint64`          | `uint64_t` |                        |
| `float32`           | `float32`    |                        |
| `float64`          | `double`   |                        |
| `bool`            | `bool`     |                        |
| `char`            | `char`     |                        |
| `string`          | see §9 (Bitwise Operators is unrelated — see Arrays §25 for string storage) | let → rodata, var → heap |
| `void` / `()`     | `void`     |                        |

`int` is an alias for `int32`; `uint` is an alias for `uint32`. Both forms are
accepted everywhere a type is valid.

---

## 4. Pointer Types

`*` in type position is a raw mutable pointer. `*const` is a raw read-only
pointer. These are the only pointer types in Vertex.

```vertex
// raw mutable pointer
var p: *int32

// read-only pointer — pointed-to data may not be modified
var p: *const int32

// nullable pointer — nil is the zero value
var p: *int32?

// pointer-to-pointer
var pp: **int32

// address-of — zero cost, returns the raw address of any value
let ptr   = &x          // *int32 — inferred
let field = &point.x    // *int32 — struct field address
let elem  = &buf[0]     // *uint8 — array element address
```

**Pointer type table:**

| Vertex              | C equivalent      |
|---------------------|-------------------|
| `name: *T`          | `T*`              |
| `name: *const T`    | `const T*`        |
| `name: *void`       | `void*`           |
| `name: *const void` | `const void*`     |
| `name: *char`       | `char*`           |
| `name: *const char` | `const char*`     |
| `name: *T?`         | nullable `T*`     |
| `name: **T`         | `T**`             |

**`let`/`var` × `const` orthogonality:**

| Vertex               | C                | Binding   | Data      |
|----------------------|------------------|-----------|-----------|
| `let name: *const T` | `const T* const` | fixed     | read-only |
| `let name: *T`       | `T* const`       | fixed     | mutable   |
| `var name: *const T` | `const T*`       | rebind OK | read-only |
| `var name: *T`       | `T*`             | rebind OK | mutable   |

**Rules:**

* `*T` is a raw mutable pointer; `*const T` is a read-only pointer. Both collapse
  to the same C pointer at runtime — `const` is a compile-time annotation only.
* `let`/`var` controls whether the binding can be rebound. `*const` controls
  whether the pointed-to data can be modified. These are orthogonal — all four
  combinations are valid.
* `&value` returns the raw address of any value. Zero cost — no allocation, no copy.
* The pointer is valid only while the backing value is alive. Passing a pointer
  to a function and then freeing the backing value is undefined behaviour.
* Reads and writes through pointer parameters and pointer receivers are
  auto-dereferenced by the compiler: `n += 1` lowers to `*n += 1` in C; `p.x`
  through a pointer receiver lowers to `p->x`.
* `*T?` is a nullable pointer. `nil` is the zero value; the compiler enforces
  null-safety through the type system.

---

## 5. Type Aliases

```vertex
type FILE   = *void
type size_t = uint64
```

**Rules:**

* `type` declares an alias — the two names are interchangeable everywhere a type
  is valid.
* Aliases may appear at package level only, not inside functions or blocks.
* Aliases resolve at compile time — no runtime representation.

---

## 6. Type Variadic Args

```vertex
class C : c {
  func printf(fmt: ...*const char)
}

func log(prefix: string, msg: ...string) {
    for m in msg {
        libc.printf("%s: %s\n", prefix, m)
    }
}
```

---

## 7. Numeric Type Conversion

All numeric conversions are explicit. There is no implicit coercion between
numeric types.

```vertex
let i: int    = 42
let f: float32  = float32(i)       // int → float32, always safe
let i2: int   = int(3.99)      // truncates toward zero → 3
let b: int8   = int8(i)        // narrowing — wraps on overflow
```

**Rules:**

* Conversion syntax is `targetType(value)` — no cast keyword.
* No implicit numeric conversion at any point.
* float32-to-integer conversion truncates toward zero.
* Narrowing integer conversions wrap on overflow, identical to `&+`, `&-`, `&*`.
* Widening conversions (e.g. `int` → `double`) are always value-preserving.

---

## 7.1 Casting — `as`

The `as` operator performs explicit type conversion. It is used for numeric widening, pointer reinterpretation, and float-to-integer truncation.

**Vertex**
```vertex

// ── pointer → pointer (no-op at runtime) ─────────────────────────────────────
var opt: int32 = 1
libc.setsockopt(sfd, 1, 2, &opt as *const char, 4)

var buf: [uint8; 256]
libc.recv(fd, &buf as *char, 256, 0)

// ── integer widening ──────────────────────────────────────────────────────────
let small: int32 = 42
let wide = small as int64          // sign-extended
let big  = small as uint64         // zero-extended (backend validates sign safety)

// ── float → int (truncate toward zero) ───────────────────────────────────────
let f: float64 = 3.99
let i = f as int32                 // → 3

// ── int → float ───────────────────────────────────────────────────────────────
let count: int32 = 7
let ratio = count as float64 / total as float64

// ── pointer → integer (reinterpret) ──────────────────────────────────────────
let ptr: *uint8 = buf.data()
let addr = ptr as uint64           // raw address value

// ── integer → pointer (reinterpret) ──────────────────────────────────────────
let mmio: uint64 = 0xFFFF_0000
let reg = mmio as *uint32          // MMIO register access

// ── chaining (left-associative) ───────────────────────────────────────────────
let x = value as int32 as int64   // (value as int32) as int64

// ── address-of then cast — & binds tighter ───────────────────────────────────
libc.memset(&header as *char, 0, size)   // (&header) as *char
```

---

## 8. Arithmetic Operators

```vertex
a + b
a - b
a * b
a / b
a % b
-a
```

---

## 9. Compound Assignment

```vertex
a += b
a -= b
a *= b
a /= b
a %= b
```

---

## 10. Bitwise Operators

```vertex
~a        // NOT
a & b     // AND
a | b     // OR
a ^ b     // XOR
a << b    // left shift
a >> b    // right shift
```

---

## 11. Overflow Operators

```vertex
a &+ b    // overflow add
a &- b    // overflow subtract
a &* b    // overflow multiply
```

---

## 12. Comparison Operators

```vertex
a == b
a != b
a >  b
a <  b
a >= b
a <= b
```

---

## 13. Logical Operators

```vertex
!a
a && b
a || b
```

---

## 14. Range Operators

```vertex
0...5     // closed
0..<5     // half-open
```

---

## 15. Ternary Operator

```vertex
condition ? a : b
```

---

## 16. Nil-Coalescing

```vertex
a ?? b
```

---

## 17. Identity Operators (classes only)

```vertex
a === b
a !== b
```

---

## 18. Operator Precedence (high → low)

| Level   | Operators                         |
|---------|-----------------------------------|
| Highest | `<<` `>>`                         |
|         | `*` `/` `%` `&*`                  |
|         | `+` `-` `&+` `&-`                 |
|         | `...` `..<`                       |
|         | `??`                              |
|         | `==` `!=` `<` `>` `<=` `>=`      |
|         | `&&`                              |
|         | `\|\|`                            |
|         | `? :`                             |
| Lowest  | `=` `+=` `-=` `*=` `/=` `%=`     |

---

## 19. If / Else / Else If

```vertex
if x > 0 {
    // positive
} else if x < 0 {
    // negative
} else {
    // zero
}
```

---

## 20. Switch

```vertex
switch x {
case 0:
    // exactly zero
case 1, 2:
    // one or two
default:
    // anything else
}
```

**String switch:**

```vertex
switch s {
case "hello":
    // ...
case "world":
    // ...
default:
    // ...
}
```

**Enum switch:**

```vertex
switch direction {
case .north:
    // ...
case .south:
    // ...
case .east:
    // ...
case .west:
    // ...
// no default required — all cases covered
}
```

**Explicit fallthrough:**

```vertex
switch x {
case 0:
    // zero
    fallthrough
case 1:
    // zero or one — reached by fallthrough from above
default:
    // other
}
```

**Rules:**

* Cases do not fall through implicitly — each case is independent.
* `fallthrough` transfers control to the next case unconditionally, without
  re-evaluating its condition.
* Multiple values per case are separated by commas.
* `default` is required unless the compiler can statically verify exhaustiveness.
* Switching on an enum with all cases covered is exhaustive — `default` is not
  required.
* An empty case body (with no `fallthrough`) is a compile error.
* `break` may be used inside a case to exit the switch early (§21).
* `switch` may appear anywhere a statement is valid.

---

## 21. Break and Continue

```vertex
for i in 0..<10 {
    if i % 2 == 0 { continue }   // skip even numbers
    if i == 7     { break }      // stop at 7
}

var n = 0
while true {
    if n >= 5 { break }
    n += 1
}
```

**Rules:**

* `break` exits the immediately enclosing `for`, `while`, or `switch` statement.
* `continue` skips the remainder of the current loop iteration and begins the next.
* `continue` is not valid inside `switch`.
* Neither `break` nor `continue` may appear inside a `defer` block.

---

## 22. Functions

```vertex
func add(a: int32, b: int32) -> int32 {
    return a + b
}

add(1, 2)
add(a: 1, b: 2)
```

**Pointer parameters:**

```vertex
func increment(n: *int32) {
    n += 1        // auto-dereferenced — lowers to *n += 1
}

var count = 0
increment(n: &count)   // count is now 1
```

**Execution strategy:**

Vertex has no `async`, `thread`, `process`, or `gpu` *function qualifiers*.
Every function is written as a single, ordinary, synchronous function — business
logic is completely decoupled from execution strategy. The caller decides how a
given call is executed by prefixing the call expression with an execution sigil
at the call site. See §39–§40 (Execution Reality Map and Execution Modifiers) for
the full model.

**Rules:**

* Parameters are immutable and passed by value by default.
* `*T` declares a pointer parameter — the function receives the raw address of
  the caller's value.
* The call site must prefix a `var` binding with `&` when passing to a `*T`
  parameter.
* Reads and writes through a pointer parameter are auto-dereferenced by the
  compiler: `n += 1` lowers to `*n += 1` in C.
* `*T` may be applied to any parameter.
* Labels are erased at the call site in the lowered C output — the C call is
  always positional.

---

## 23. While Loop

```vertex
var i = 0
while i < 5 {
    i += 1
}
```

---

## 24. For-In Loop

```vertex
// Range — half-open
for i in 0..<5 {
    // i: int32
}

// Range — closed
for i in 0...5 {
    // i: int32, includes 5
}

// Array
let nums = [1, 2, 3]
for n in nums {
    // n: int32
}
```

**Rules:**

* `for i in range` binds the loop variable as the range element type (`int32` for
  integer ranges).
* `for item in array` binds each element in order, from index 0 to the last.
* The loop variable is immutable — it may not be assigned inside the body.
* `break` and `continue` are valid inside any `for-in` body (§21).

---

## 25. Arrays

**Declaration forms at a glance:**

| Form | Storage | Growable | Notes |
|------|---------|----------|-------|
| `var buf: [uint8; 1024]` | stack | no | zero-filled, mutable elements |
| `var arr: [int32; 3] = [1, 2, 3]` | stack | no | mutable, initialized |
| `let arr = [1, 2, 3]` | stack / rodata | no | immutable, inferred `[int32; 3]` |
| `let arr: [uint8; 3] = [0xFF, 0x00, 0xAB]` | stack / rodata | no | immutable, annotated |
| `var x: [int32] = []` | heap | yes | empty dynamic |
| `var x = [1, 2, 3]` | heap | yes | dynamic from literal |
| `var x: [int32] = [1, 2, 3]` | heap | yes | annotated dynamic |

The rule: `[T; N]` → always fixed stack. `[T]` → always dynamic heap. `let` → immutable. `var` → mutable.

---

### 25.1 Fixed Arrays

Fixed arrays are stack-allocated. Size is fixed at compile time and is part of the type — `[uint8; 1024]` and `[uint8; 512]` are distinct types. `push`, `pop`, `shift`, `unshift`, `.reserve()`, and `.delete()` are compile errors on any fixed array.

```vertex
// zero-filled mutable — annotation only, no = required
var buf:  [uint8; 1024]
var nums: [int32; 16]

// non-zero fill — declare then fill
var mask: [uint8; 64]
mask.fill(0xFF)

// mutable with initializer
var coords: [int32; 3] = [10, 20, 30]

// fixed immutable literal — let binding
let nums  = [1, 2, 3]                         // inferred: [int32; 3]
let flags: [uint8; 3] = [0xFF, 0x00, 0xAB]

// trailing comma valid in multiline literals
let bytes: [uint8; 3] = [
    0xFF,
    0x00,
    0xAB,
]

// nested (multidimensional)
let matrix: [[float32; 2]; 2] = [
    [0.0, 1.0],
    [1.0, 0.0],
]

// read / write
let first = buf[0]
buf[0]    = 255     // requires var binding
```

**Rules:**

* `var name: [T; N]` declares a zero-filled stack array of `N` elements. No `= ` required — zero-fill is implicit.
* `N` must be a compile-time integer literal.
* `var name: [T; N] = [...]` initializes with explicit values. The literal must contain exactly `N` elements.
* `let` binding — all elements are immutable; subscript write is a compile error.
* `var` binding — elements are mutable; subscript write is allowed. Size is still fixed.
* `[T; N]` and `[T; M]` are distinct types when `N ≠ M`.
* `push`, `pop`, `shift`, `unshift`, `.reserve()`, and `.delete()` are compile errors on any fixed array.
* No `.delete()` needed — fixed arrays are freed automatically at scope exit.
* Index bounds are not checked at compile time — out-of-bounds is a runtime error.

---

### 25.2 Dynamic Arrays

Dynamic arrays are heap-allocated and growable. `var` with a `[T]` type (no size) always produces a dynamic array.

```vertex
// empty — type annotation required
var items:   [int32] = []
var players: [Player] = []
var buf:     [uint8] = []

// from literal — var + = [...] = dynamic
var scores = [10, 20, 30]             // [int32] inferred
var names: [string] = ["a", "b"]

// capacity hint — avoids realloc churn when final count is known upfront
var items: [int32] = []
items.reserve(64)

defer items.delete()
```

**Rules:**

* `var x: [T] = []` creates an empty dynamic array. The type annotation is required — element type cannot be inferred from `[]` alone.
* `var x = [v1, v2, v3]` creates a dynamic array. Element type is inferred from the literal. `var` with no size annotation drives the heap allocation.
* `var x: [T] = [v1, v2, v3]` — annotated dynamic array with initial values.
* `let x = [v1, v2, v3]` creates a **fixed immutable** array — `let` with a literal infers `[T; N]`, not `[T]`. The array is stack-allocated and `.push()` is a compile error.
* `.reserve(n)` pre-allocates `n` slots without setting length. Valid on dynamic arrays only.
* Dynamic arrays are heap-allocated. The caller must call `.delete()` — failing to do so is a memory leak.
* `defer items.delete()` is the recommended pattern.

---

### 25.3 Add / Remove

```vertex
items.push(42)            // add to end
items.unshift(0)          // add to front

let last  = items.pop()   // remove from end,   returns T?
let first = items.shift() // remove from front, returns T?
```

**Rules:**

* `push`, `unshift`, `pop`, and `shift` are only valid on dynamic arrays. Calling them on a fixed array is a compile error.
* `push` and `unshift` grow the array automatically.
* `pop` and `shift` return `T?` — `nil` if the array is empty.

---

### 25.4 Access

```vertex
let n    = items.length   // element count
let x    = items[0]       // subscript read
items[0] = 99             // subscript write — requires var binding
```

---

### 25.5 Search

```vertex
let idx = items.indexOf(42)      // int32  (-1 if not found)
let has = items.includes(42)     // bool

let val = items.find(func(x: int32) -> bool {
    return x > 10
})                               // T?

let i = items.findIndex(func(x: int32) -> bool {
    return x > 10
})                               // int32  (-1 if not found)
```

---

### 25.6 In-Place Mutation

These methods mutate the array without allocating — no `.delete()` needed on the result.

```vertex
items.reserve(64)   // pre-allocate capacity — dynamic arrays only

items.sort(func(a: int32, b: int32) -> int32 {
    return a - b
})

items.reverse()

items.fill(0)
items.fill(0, from: 1, to: 3)
```

---

### 25.7 Methods That Return a New Array

These methods allocate a new array — the caller must call `.delete()` on the result.

```vertex
var doubled = items.map(func(x: int32) -> int32 {
    return x * 2
})
defer doubled.delete()

var evens = items.filter(func(x: int32) -> bool {
    return x % 2 == 0
})
defer evens.delete()

var sub = items.slice(1, 3)
defer sub.delete()

var all = a.concat(b)
defer all.delete()
```

---

### 25.8 Iteration

```vertex
items.forEach(func(x: int32) {
    // process each element
})
```

---

### 25.9 Struct Arrays

Structs are copied by value on `push` — consistent with Vertex value semantics.

```vertex
struct Vec2 {
    x: float32
    y: float32
}

struct Player {
    id:       int32
    position: Vec2
    health:   int32
}

var players: [Player] = []
defer players.delete()

players.push(Player{
    id:       1,
    position: Vec2{x: 0.0, y: 0.0},
    health:   100,
})

// field access and mutation
let hp            = players[0].health
players[0].health = 50

// search
let idx = players.findIndex(func(p: Player) -> bool {
    return p.id == 2
})

let found = players.find(func(p: Player) -> bool {
    return p.health < 100
})

// sort by health
players.sort(func(a: Player, b: Player) -> int32 {
    return a.health - b.health
})

// filter — new array, must delete
var alive = players.filter(func(p: Player) -> bool {
    return p.health > 0
})
defer alive.delete()

// map to ids — new array, must delete
var ids = players.map(func(p: Player) -> int32 {
    return p.id
})
defer ids.delete()

// iterate
players.forEach(func(p: Player) {
    // process each player
})
```

---

### 25.10 Memory Rules

| Form / Method | Allocates | Action required |
|---|---|---|
| `var buf: [T; N]` | no (stack) | nothing |
| `let arr = [...]` | no (stack / rodata) | nothing |
| `var x: [T] = []` | yes (heap) | `defer x.delete()` |
| `var x = [...]` | yes (heap) | `defer x.delete()` |
| `push` `unshift` `fill` `sort` `reverse` `reserve` | no | nothing |
| `pop` `shift` | no | nothing |
| `map` `filter` `slice` `concat` | yes | `defer result.delete()` |

---

## 26. Maps

```vertex
// short form — type inferred
let somemap = {"a": 1, "b": 2}
let val = somemap["a"]           // val: int32? — nil if key absent

// long form — explicit type
let typedMap: map[string]int32 = {"a": 1, "b": 2}

// empty heap allocation
var config = map[string]int32()
defer config.delete()

// mutation
config["debug"] = 1
config["verbose"] = 0
config["debug"] = nil            // removes key

```

**Rules:**

* Map literals use brace syntax: `{"key": value, ...}`.
* The formal type signature for a map is `map[KeyType]ValueType`.
* `map[K]V()` creates an empty, heap-allocated map.
* Key access always returns an optional (`T?`) — the key may not be present.
* Key write requires the map binding to be `var`.
* Assigning `nil` to a key removes it from the map.
* Maps are heap-allocated and must be freed with `.delete()`.
* The caller is responsible for calling `.delete()` — failing to do so is a memory leak.

---

## 27. Optionals

```vertex
// scalar optional
var maybe: int32? = nil
maybe = 5
if let val = maybe {
    // val: int32 — unwrapped, safe to use
}

// pointer / class optional
var animal: Animal? = nil
if let a = animal { }
let result = animal ?? defaultAnimal
```

**Rules:**

* Pointer and class optionals lower to nullable pointers — `nil` is `NULL`.
* Scalar optionals lower to a tagged struct `{ T value; bool has_value; }`.
* Use `if let` to safely unwrap any optional.
* `??` provides a default value when the optional is `nil`.

---

## 28. Structs

```vertex
struct Point {
    x: int32
    y: int32
}

let p  = Point{x: 3, y: 4}
let p2 = p
let n  = p.x

var q = Point{x: 3, y: 4}
q.y = 10
```

**Multiline form:**

```vertex
let p = Point{
    x: 3,
    y: 4,
}
```

**Nested field initialization:**

```vertex
struct Line {
    start: Point
    end:   Point
}

let l = Line{
    start: Point{x: 0, y: 0},
    end:   Point{x: 10, y: 10},
}
```

**Rules:**

* Struct fields are declared as `name: type` — no `let` or `var` keyword.
* Mutability is determined entirely by the binding at the declaration site.
* A `let` binding freezes all fields — no field may be reassigned.
* A `var` binding opens all fields — any field may be reassigned.
* Struct literals use brace syntax: `TypeName{field: value, ...}`.
* All field labels are required — positional initialization is not supported.
* Fields may appear in any order inside the literal.
* Trailing commas are valid in multiline struct literals.
* All fields must be provided — partial initialization is a compile error.
* Struct literals may not appear directly as the condition of `if`, `for`, or
  `switch` statements. Wrap in parentheses to disambiguate:
  `if (Point{x: 1, y: 2} == p) { }`.
* Structs are pure data — no vtable, no heap allocation.
* Assignment always produces a full copy.
* Structs may not contain class fields that imply ownership semantics.
* Field access via dot notation compiles to a direct byte offset calculation.
* Struct definitions may not appear inside other struct or class definitions.

---

## 29. Associated Functions (Receiver Syntax)

A function declared with a receiver argument immediately before the function
name is an associated function of the receiver's type.

```vertex
// value receiver — receives a copy; mutations do not affect the caller
func (p: Point) describe() {
    let n = p.x
}

// pointer receiver — receives the address; mutations affect the caller's binding
func (p: *Point) reset() {
    p.x = 0    // auto-dereferenced — lowers to p->x = 0
    p.y = 0
}

p.describe()
p.reset()      // compiler inserts & automatically for pointer receiver
```

**Rules:**

* The receiver is declared in its own parentheses immediately after `func` and
  before the function name: `func (receiverName: Type) functionName(params)`.
* The receiver name is chosen by the developer — typically a short abbreviation
  of the type name.
* Value receiver `(p: T)` — the receiver is passed by value (copied). Mutations
  do not affect the caller.
* Pointer receiver `(p: *T)` — the receiver is passed as a pointer. Mutations
  affect the caller's binding.
* For pointer receivers, the compiler automatically inserts `&` at call sites —
  the caller writes `p.reset()`, not `reset(&p)`.
* Reads and writes through a pointer receiver are auto-dereferenced: `.x`
  lowers to `->x` in C.
* `self` and `this` are absent from the language — the receiver is named
  explicitly.
* To write a utility function without associating it as a method, place the type
  in the standard parameter list instead of using the receiver block.

---

## 30. Enums

```vertex
enum Direction {
    case north
    case south
    case east
    case west
}

enum Permission {
    case read, write, execute
}
```

**Raw values — int:**

```vertex
enum Status: int {
    case inactive = 0
    case active   = 1
    case pending  = 2
}

let s   = Status.active
let raw = Status.active.rawValue    // 1

let fromRaw: Status? = Status(rawValue: 1)
```

**Raw values — string:**

```vertex
enum Color: string {
    case red   = "red"
    case green = "green"
    case blue  = "blue"
}

enum Planet: string {
    case mercury   // rawValue = "mercury"
    case venus     // rawValue = "venus"
    case earth     // rawValue = "earth"
}
```

**Rules:**

* Cases are declared with the `case` keyword, one or more per line,
  comma-separated.
* Enum values are accessed via dot notation: `EnumType.caseName`.
* When the type is known from context, the type name may be omitted: `.caseName`.
* Raw value types must be `int` (or `int32`) or `string`.
* `int` raw values auto-increment from the previous value if omitted; the first
  case defaults to `0` if no value is given.
* `string` raw values default to the case name as a string literal if omitted.
* `.rawValue` accesses the underlying raw value on a raw-value enum.
* `EnumType(rawValue:)` constructs from a raw value and returns `EnumType?`.
* Enums support `==` and `!=`. Raw-value enums also support `<`, `>`, `<=`, `>=`.
* A `switch` over an enum with all cases covered is exhaustive — `default` is not
  required.
* Enums are value types — assignment copies.
* Enums may not be nested inside structs or classes.
* Associated values are not supported in 2.1 (deferred).

---

## 31. Classes

```vertex
class Animal {
    name: string
}

func (a: *Animal) init(name: string) {
    a.name = name
}

func (a: *Animal) deinit() {
    // runs before memory is freed
}

let a = Animal(name: "Rex")
a.delete()
```

**Rules:**

* Class fields are declared as `name: type` — no `let` or `var` keyword.
* Mutability is determined entirely by the binding at the declaration site.
* A `let` binding freezes all fields — no field may be reassigned.
* A `var` binding opens all fields — any field may be reassigned.
* Classes are heap-allocated — the runtime cost is exactly what the programmer pays.
* Assignment passes a reference — two variables may point to the same object.
* Identity operators `===` and `!==` compare references, not values.
* Inheritance is not supported — classes are standalone types.
* A class may contain fields whose type is a struct.
* `init` is a reserved associated function name called automatically after
  allocation. It must be declared with a pointer receiver
  (e.g., `func (a: *Animal) init()`).
* `deinit` is a reserved associated function name. It runs automatically when
  `.delete()` is called. It must be declared with a pointer receiver
  (e.g., `func (a: *Animal) deinit()`).
* Neither `init` nor `deinit` may be called directly.
* If no `func init` is declared, the compiler provides a default memberwise
  initializer.
* The programmer is responsible for calling `.delete()` on class instances.
* Failing to call `.delete()` on a class instance is a memory leak.
* Class definitions may not appear inside other class or struct definitions.

---

## 31.1 Reference Counting — `.new()`

```vertex
let a = Animal(name: "Rex").new()
let b = a                           // count = 2
// b scope ends — count = 1
// a scope ends — count = 0, deinit called, freed
```

**Weak references:**

```vertex
let a = Animal(name: "Rex").new()
weak let b = a                   // b: Animal? — non-owning, count stays 1

if let animal = b {
    // safe — animal is Animal within this scope
}
```

**Rules:**

* `.new()` is postfix on any class instantiation expression.
* `.new()` and `.delete()` are mutually exclusive.
* `weak let` declares a non-owning reference. It does not increment the count.
* `weak let` produces a value of type `T?`. Use `if let` to safely unwrap
  before use.
* After owning references reach zero, all `weak` references become `nil`.
* `weak` is only valid on ref-counted instances (`.new()`).

---

## 32. Defer

```vertex
let a = Animal(name: "Rex")
defer a.delete()
```

**Anonymous function form:**

```vertex
defer func() { cleanup(a) }()
```

**Multiple defers (LIFO):**

```vertex
defer a.delete()           // runs second
defer b.delete()           // runs first
```

**Rules:**

* `defer` takes a direct function call — no surrounding braces.
* For multi-statement cleanup, use `defer func() { ... }()` — the trailing `()`
  invokes the anonymous function, deferring its execution to scope exit.
* `defer` executes when the immediately enclosing scope exits.
* Multiple `defer` statements in the same scope run in reverse declaration order
  (LIFO).
* `defer` may appear anywhere in a function body — not only at the top.
* The deferred call may not contain `return`, `break`, or `continue`.
* `defer` is not valid at the top level — only inside function bodies.

---

## 33. Generics (unconstrained)

```vertex
func identity<T>(value: T) -> T {
    return value
}

struct Box<T> {
    value: T
}

let b      = Box<T>{value: 42}
let result = identity<T>(value: "hello")
```

---

## 34. Import Declarations

```vertex
import "github.com/something"

import (
    "github.com/something"
    "github.com/something/else"
)
```

**Rules:**

* Import paths are double-quoted string literals.
* The grouped form parenthesizes one or more newline-separated paths — no commas.
* Imports must appear at the top of a file, after any `package` and `build`
  declarations.

---

## 35. First-Class Function Types

```vertex
// variable holding a function
let double:    func(int32) -> int32
let predicate: func(int32) -> bool
let transform: func(string, int32) -> string

// void return — arrow omitted
let onFire: func(int32)

// function type as a parameter
func apply(values: [int32], f: func(int32) -> int32) -> [int32] { }

// function type as a return type
func makeAdder(n: int32) -> func(int32) -> int32 { }

// pointer parameter in a function type
func run(n: *int32, f: func(*int32)) { }

// calling a function value — standard call syntax
let result = float32(21)
```

**Rules:**

* Function type syntax is `func(ParamTypes) -> ReturnType`.
* When the return type is `void`, the arrow and return type are omitted:
  `func(int32)`.
* `*T` in a function type signature indicates a pointer parameter — the same
  rules as pointer parameters in named functions (§22) apply.
* Function types are value types — assignment copies the callable reference.
* Parameter names are not part of the type — only the types matter.

---

## 36. Anonymous Functions

```vertex
// stored in a variable
let double = func(n: int32) -> int32 { return n * 2 }

// void return — arrow omitted
let log = func(n: int32) { print(n) }

// passed inline — higher-order function pattern
let doubled = process(nums, func(n: int32) -> int32 {
    return n * 2
})

// passed inline — callback registration
emitter.on(func(n: int32) -> int32 {
    return n * 2
})
```

**Capture — value semantics:**

```vertex
let factor = 3
let multiply = func(n: int32) -> int32 {
    return n * factor    // factor captured by value at creation
}

var count = 0
let increment = func() {
    count += 1           // compile error — captured copy, not the original
}
```

**Writeback via pointer parameter:**

```vertex
func run(n: *int32, f: func(*int32)) {
    f(n)          // n is already a pointer — pass directly
}

var total = 0
run(n: &total, f: func(n: *int32) {
    n += 10       // auto-dereferenced — total is now 10
})
```

**Rules:**

* Anonymous function syntax is `func(params) -> ReturnType { body }` — identical
  to a named function declaration minus the name.
* Anonymous functions capture variables from the enclosing scope by value at the
  point of creation.
* Captured values are copied — mutations inside the anonymous function do not
  affect the original binding.
* To write back through a variable, pass it explicitly as a pointer parameter
  (§22) — capture alone cannot produce writeback.
* Pointer parameters (`*T`) inside an anonymous function follow the same rules as
  in named functions (§22).
* `return` inside an anonymous function returns from the anonymous function, not
  the enclosing function.
* Anonymous functions may not refer to themselves by name — they are not
  recursive. Recursion requires a named function.
* Anonymous functions are valid anywhere an expression is valid.
* The inferred type of an anonymous function is `func(ParamTypes) -> ReturnType`
  (§35).

**Concurrent anonymous functions:**

An anonymous function carries no execution qualifier of its own. Instead, an
execution sigil is placed before the entire call expression — exactly as it
would be for a named function:

```vertex
let result = thread func(seed: int32) -> float32 {
    return crunchNumbers(seed)
}(105)
```

See §39–§40 for the execution sigils (`async`, `thread`, `process`, `gpu`) and
§44 for the single-return vs. stream channel pattern this produces.

---

## 37. Tuples

Vertex has first-class tuples as stack-allocated value types. They enable
multi-value returns from functions without heap allocation or defining a named
struct.

```vertex
let pair  = (1, true)
let point = (x: 10, y: 20)
let nothing: () = ()
```

**Destructuring:**

```vertex
let (a, b) = pair
let (x, y): (int32, int32) = (14, 17)
```

**Function return — unlabeled:**

```vertex
func divmod(a: int32, b: int32) -> (int32, int32) {
    return (a / b, a % b)
}

let (quotient, remainder) = divmod(10, 3)
```

**Function return — labeled:**

```vertex
func minMax(values: [int32]) -> (min: int32, max: int32) {
    return (0, 100)
}

let (lo, hi) = minMax(values: [3, 1, 4])
```

Tuples are zero-overhead — the compiler lowers them directly to adjacent stack
values in C. They are the foundation of the getter/setter pattern used
throughout the state system (§46).

**Tuples over channels:**

Channels can carry tuples for paired data, such as a value alongside a validity
flag:

```vertex
let stream: chan (int32, bool) = {cap: 64}   // value + validity flag

select {
case (val, ok) = stream.receive():
    if ok { print(val) }
}
```

**Rules:**

* `()` is the empty tuple and is an alias for `void`.
* A single-element parenthesised expression `(x)` has the type of `x`, not a
  tuple.
* Element labels are optional. Unlabelled elements are only accessible via
  destructuring.
* Two tuple types are identical if they share the same element types and labels
  in order.
* `==`, `!=`, `<`, `>`, `<=`, `>=` work on tuples whose elements are all
  comparable, up to 6 elements. Labels are ignored during comparison.
* Tuples are value types — assignment copies all elements.

---

## 38. Error Handling

### 38.1 Optionals — absence without context

```vertex
func findUser(id: int32) -> User? {
    if id < 0 { return nil }
    return User(id)
}

if let user = findUser(id: 1) { }
let name = findUser(id: -1) ?? defaultUser
```

### 38.2 Tuples — multiple returns, caller decides

```vertex
func divide(a: int32, b: int32) -> (int32, string?) {
    if b == 0 { return (0, "division by zero") }
    return (a / b, nil)
}

let (result, err) = divide(a: 10, b: 0)
if err != nil { }
```

### 38.3 Result — explicit Ok/Err

```vertex
func parseInt(s: string) -> Result(int32, string) {
    if s == "" { return Result(Err, "empty string") }
    return Result(Ok, 42)
}
```

**Consuming with `if let`:**

```vertex
if let value = parseInt(s: "42") {
    // value: int32
}
```

**Consuming with `switch`:**

```vertex
switch parseInt(s: "42") {
case Ok(let value):
    // value: int32
case Err(let err):
    // err: string
}
```

**Propagating with `.try()`:**

```vertex
func process(s: string) -> Result(int32, string) {
    let n = parseInt(s: s).try()
    let d = divide(a: n, b: 2).try()
    return Result(Ok, d)
}
```

**Rules:**

* `Result(Ok, value)` and `Result(Err, error)` are the only valid construction
  forms.
* `if let` on a `Result` binds the `Ok` value only — use `switch` to inspect
  `Err`.
* `.try()` may only appear inside a function whose return type is `Result(T, E)`.

### 38.4 Choosing the Right Primitive

| Situation                               | Use             |
|-----------------------------------------|-----------------|
| Value may simply not exist              | `T?`            |
| Caller needs value and error together   | `(T, E?)` tuple |
| Caller must handle Ok or Err explicitly | `Result(T, E)`  |

---

# Concurrency Architecture (v2.0)

Vertex prioritizes absolute hardware transparency, zero hidden runtime overhead,
and explicit memory boundaries. Concurrency is built on a small set of
orthogonal primitives — execution sigils, channels, and broadcast state — rather
than a bundled runtime or a separate `Promise`/`Future`/`actor` type system.

## 39. The Execution Reality Map

Vertex completely decouples *business logic* from *execution strategy*. The
developer writes standard functions (§22), and the caller dictates the
execution context using prefix sigils at the call site.

| Prefix Sigil | The Vertex Abstraction | The C/OS Reality Under the Hood | Best For |
| --- | --- | --- | --- |
| `thread` | Shared-memory concurrency | Spawns a real OS thread (`pthread_create`). Has a full 2MB+ OS stack. | Heavy CPU work, blocking C-library calls, `time.sleep()`. |
| `process` | Isolated-memory concurrency | Re-executes the **current binary** via `execve`/`CreateProcess` with `--process-func <id> --channel-id <id>`. The child reconnects to a compile-time ring buffer by channel ID, runs its function, sends its result, and exits. No `fork()` — fully cross-platform. | Sandboxing unsafe code, multi-socket CPU systems. |
| `async` | Non-blocking event loop | **Zero threads spawned.** Compiler rewrites the function into a State Machine (C `struct` + `switch`). Runs cooperatively on the Main Thread via `epoll`/`kqueue`. | Millions of idle network connections, UI thread tasks, state effects. |
| `gpu` | Hardware acceleration | Compiles to PTX/SPIR-V. CPU executes `dlopen` to the CUDA/Metal driver and dispatches the kernel asynchronously. | Massive matrix math, AI inference. |

---

## 40. Execution Modifiers (Prefix Sigils)

Execution modifiers are applied directly at the call site, providing immediate
visual clarity regarding memory boundaries and execution contexts.

```vertex
let a = async fetch_network(id: 1)
let b = thread heavy_compute(data: x)
let c = process isolated_task()

// GPU requires hardware configuration (blocks/threads)
let d = gpu(blocks: 16, threads: 256) matrix_mult(x, y)
```

**Rules:**

* The four sigils — `async`, `thread`, `process`, `gpu` — are mutually
  exclusive prefixes on a call expression, not function qualifiers.
* `gpu` accepts an optional configuration list `(blocks: n, threads: n)`
  controlling grid/block dispatch.
* The same function, written once with no qualifier, may be called with any of
  the four sigils at different call sites.
* Calls returning a value (`-> T`) become channel-returning expressions — see
  §44, The Channel Dichotomy.

---

## 41. The `process` Execution Model

### How It Works: Binary Re-Entry via Channel ID

When the compiler sees `process somefunc()`, it:

1. Allocates a ring buffer channel with a **compile-time-stable ID** (derived from the call site).
2. Re-executes the current binary via `execve`/`CreateProcess`, passing only two flags — the function to run and the channel to connect to.
3. The child reconnects to that ring buffer by ID, runs its function, sends its result, and exits.

```
# normal run
./main

# compiler-spawned child
./main --process-func some_func_ab3f2 --channel-id 234234978
```

No argument serialization. No `argv` blobs. The channel ID is the entire
handshake — both sides already know its type from the compiled binary.

### The Generated Entrypoint Switch

```c
int main(int argc, char** argv) {

    /* ── compiler-generated process dispatch ── always runs first ── */
    if (argc >= 5 && strcmp(argv[1], "--process-func") == 0
                  && strcmp(argv[3], "--channel-id")   == 0) {

        const char* func_id = argv[2];
        const char* chan_id  = argv[4];

        if (strcmp(func_id, "some_func_ab3f2") == 0) {
            _vtx_proc_some_func(chan_id);   /* connect to ring buffer, run, exit */
            return 0;
        }
        if (strcmp(func_id, "crunch_data_7b812") == 0) {
            _vtx_proc_crunch_data(chan_id);
            return 0;
        }

        fprintf(stderr, "vertex: unknown process func: %s\n", func_id);
        return 1;
    }

    /* ── normal main() body ── never reached by child ── */
    ...
}
```

### What the Channel ID Is

The channel ID is a compile-time integer lowered at the call site — stable
across runs as long as the function signature doesn't change. The parent
creates the ring buffer before spawning; the child opens it by that same ID. No
negotiation at runtime.

```vertex
// what the developer writes
let result = process somefunc()
let val    = result.receive()

// what the compiler lowers (parent side):
// 1. allocate ring buffer, id = 234234978  ← compile-time constant
// 2. execve("./main", ["--process-func", "some_func_ab3f2",
//                      "--channel-id",   "234234978"])
// 3. block on ring buffer receive

// child side — compiler-generated wrapper:
// _vtx_proc_some_func(chan_id):
//     ch = ringbuf_open(chan_id)   // reconnect to parent's buffer by ID
//     ch.send(somefunc())          // run, write result
//     exit(0)
```

### What the Child Does and Does Not Run

| Runs in child | Does NOT run in child |
|---|---|
| Compiler dispatch preamble | `main()` body |
| Target function | Any `state` subscriptions from `main()` |
| Ring buffer write + `exit(0)` | `runtime.loop()` |
| | Any `async` effects registered in `main()` |

This guarantees zero cross-contamination between the parent's event loop and the
child's isolated execution.

### Runtime Transport by Context

The `chan T` primitive (§43) is unified across all execution contexts. The
underlying transport is swapped out by the compiler based on which prefix sigil
is in use:

| Context | Transport | Reason |
|---|---|---|
| `async` | Shared memory, non-blocking | Same thread — state machine resumes in place |
| `thread` | Shared memory, lightweight | Same address space — direct queue hand-off |
| `process` | Ring buffer, high-speed IPC | Separate address space — ring buffer opened by ID on both sides |

The call site looks identical in all three cases. The channel ID mechanism is
what lets `process` match that interface without any special serialization
protocol.

---

## 42. The Channel Dichotomy: Single-Return vs. Streams

Vertex eliminates the need for separate `Promise` or `Future` types. All
cross-boundary communication happens via channels (`chan T`, §43). The compiler
enforces a strict two-path rule based on the function's return type.

### Path A: The Single-Return (Auto-Channeling)

If a function returns a value (`-> T`), the compiler assumes it is a one-off
computation. It automatically generates a 1-capacity channel, injects `.send()`
and `.close()` into the generated C wrapper, and returns the channel to the
caller.

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)

let final_data = worker.receive()
```

### Path B: The Stream (Explicit Channels)

If a function returns nothing (`void` / `()`), the compiler assumes it is a
long-running daemon or stream. The developer explicitly allocates and passes
channels as parameters, retaining full control over buffer capacity and
multi-channel pipelines.

```vertex
let out_stream: chan float32 = {cap: 64}

thread func(data: [float32], ch: chan float32) {
    for chunk in data {
        ch.send(process(chunk))
    }
    ch.close()
}(dataset, out_stream)

while let chunk = out_stream.tryReceive() {
    print(chunk)
}
```

---

## 43. Channels

### 43.1 Channel Initialization

A channel is declared with an explicit type annotation and initialized with a
brace literal. An empty brace `{}` produces an unbuffered channel. `{cap: N}`
produces a buffered channel with capacity `N`.

```vertex
// unbuffered — blocks on send until receiver is ready
let ch1: chan float32 = {}

// buffered — capacity set via cap field
let ch2: chan int32 = {cap: 64}

// pointer type — type annotation left, initializer right, no ambiguity
let ch3: chan *const char = {cap: 32}
```

**Rules:**

* The type annotation is required — the element type cannot be inferred from
  `{}` alone.
* `{}` declares an unbuffered channel. Send blocks until a receiver is ready.
* `{cap: N}` declares a buffered channel. Send blocks only when the buffer is
  full.
* `N` must be a compile-time integer literal greater than zero.

### 43.2 Channel API

All channel operations are method calls. There is no operator syntax. This
keeps one consistent style across the entire channel primitive regardless of
whether the operation is blocking, non-blocking, or closing.

```vertex
ch.send(val)          // blocking send — waits if buffer is full
ch.receive()          // blocking receive — waits until a value arrives
ch.trySend(val)       // non-blocking send — returns bool, false if full
ch.tryReceive()       // non-blocking receive — returns immediately
ch.close()            // closes the channel, signals no more values
ch.subscribe()        // returns a new personal chan T for broadcast state
```

`tryReceive()` returns an optional, allowing clean `if let` handling:

```vertex
if let val = ch.tryReceive() {
    print(val)
}
```

**Operation summary:**

| Method          | Blocking | Returns  | Behaviour                            |
|-----------------|----------|----------|---------------------------------------|
| `.send(value)`  | yes      | `void`   | waits until value is accepted          |
| `.receive()`    | yes      | `T`      | waits until value is available         |
| `.trySend(v)`   | no       | `bool`   | false if full or no receiver ready     |
| `.tryReceive()` | no       | `T?`     | nil if channel is empty                |
| `.close()`      | no       | `void`   | always completes immediately           |
| `.subscribe()`  | no       | `chan T` | new personal channel for broadcast state |

**Rules:**

* `.send()` blocks when the buffer is full or the channel is unbuffered and no
  receiver is ready.
* `.receive()` blocks until a value is available.
* `.trySend()` returns `false` immediately if the channel cannot accept the
  value — it never blocks.
* `.tryReceive()` returns `nil` immediately if no value is available — it never
  blocks.
* `.send()` or `.trySend()` on a closed channel is a runtime error.
* `.receive()` or `.tryReceive()` on a closed, empty channel is a runtime error.
* `.close()` always completes immediately.
* `.subscribe()` is most commonly used with `state` (§46) — each subscriber
  receives its own `chan T` and sees every broadcast.
* Runtime transport (shared memory vs. ring buffer) varies by execution context
  — see §41, Runtime Transport by Context.

---

## 44. Multiplexing (`select` and Polling)

Because all execution contexts communicate via the same `chan T` primitive,
they can be multiplexed universally.

**Method A: The Polling Loop (Non-Blocking)**

For systems programming requiring tight control over CPU yielding:

```vertex
let task1 = process crunch_data()
let task2 = thread fetch_network()

var waiting = true
while waiting {
    if let a = task1.tryReceive() {
        print("Process won")
        waiting = false
    } else if let b = task2.tryReceive() {
        print("Thread won")
        waiting = false
    } else {
        runtime.yield()
    }
}
```

**Method B: The `select` Block (Zero-CPU Sleeping)**

For high-performance multiplexing. The `select` block safely suspends the
thread (0% CPU) until a channel is ready.

```vertex
select {
case a = task1.receive():
    print("Process won")
case b = task2.receive():
    print("Thread won")
default:
    // adding 'default' makes the select instantly non-blocking
    print("Doing other work...")
}
```

**Rules:**

* `select` evaluates each `case`'s `.receive()` concurrently and runs the body
  of whichever channel becomes ready first.
* An optional `default` case makes the entire `select` non-blocking — if no
  channel is ready immediately, `default` runs instead.
* Without `default`, `select` suspends with 0% CPU usage until a case is ready.
* `case` bindings (e.g. `a = task1.receive()`) are scoped to that case's body
  only.

---

## 45. The State System

### Philosophy

Vertex's `state` keyword declares a **reactive broadcast primitive**. It is the
one additional concept built on top of `chan T`, covering the case where
multiple subscribers need the same current value simultaneously.

```
chan T    →  point-to-point, FIFO, one consumer per message
state T  →  broadcast, current value, many subscribers, module-owned
```

Under the hood, `state` allocates a value store and a fan-out mechanism. When
`setState` is called, the new value is stored and sent to every subscriber's
individual `chan T` (via `.subscribe()`, §43.2). No subscriber competes with
another. Every subscriber sees every update.

### Declaration

State is always declared using the inline struct form at **package level** in
its own module file. Every field carries a default value. The `state` keyword
is reserved.

```vertex
// package appstate
state WorkerState {
    count:   int32       = 0
    message: *const char = ""
    done:    bool        = false
}
```

### Consuming State

Calling the state by name returns a `(snap, setState)` tuple (§37). `snap` is a
reactive handle typed `state WorkerState` — field access works transparently
through it. The developer names both sides freely.

```vertex
import "github.com/youruser/appstate"

let (snap, setState) = appstate.WorkerState()

// snap      — current value at time of subscription
// setState  — broadcasts a new value to all subscribers

snap.count
snap.message
snap.done
```

### Updating State

`setState` takes a full struct literal. Partial updates are not supported — the
compiler enforces that all fields are present, so adding a field to the state
definition produces a compile error at every call site.

```vertex
setState(WorkerState{ count: 1, message: "processing", done: false })
```

Named parameters are also valid:

```vertex
setState(count: 1, message: "processing", done: false)
```

**Rules:**

* `state` declarations may appear at package level only, in their own module
  file.
* Every field of a `state` struct must declare a default value.
* Calling the state's name returns `(snap, setState)` — a tuple (§37).
* `setState` requires every field to be present in each call — partial updates
  are a compile error.
* Every subscriber's `chan T` (obtained explicitly via `.subscribe()`, or
  implicitly via an `async` effect, §46) receives every broadcast — no
  competition between subscribers.

---

## 46. Async State Effects

### The Problem

Subscribing to state changes by hand requires calling `.subscribe()`, entering a
`while true` loop, and calling `.receive()` on every iteration. Writing this for
every state listener is boilerplate.

### The Solution: `state T` Parameters

When an `async` function declares a parameter with type `state T`, the compiler
automatically generates the subscribe, loop, and receive machinery. The
developer passes `snap` at the call site — its type `state T` is the signal the
compiler uses to wire up the subscription.

```vertex
let (snap, setState) = WorkerState()

// what the developer writes
async func(s: state WorkerState) {
    io.printf("count: %d  msg: %s\n", s.count, s.message)

    if s.done {
        runtime.exit(0)
    }
}(snap)
```

```vertex
// what the compiler emits
async {
    let __ch = WorkerState.subscribe()
    while true {
        let s = __ch.receive()
        io.printf("count: %d  msg: %s\n", s.count, s.message)

        if s.done {
            runtime.exit(0)
        }
    }
}
```

The `async` prefix (§40) confirms the effect runs on the **main thread event
loop** — safe for UI updates, zero additional threads spawned.

Multiple `state T` parameters subscribe to all of them simultaneously:

```vertex
let (workerSnap, setWorker) = WorkerState()
let (cfgSnap, setCfg)       = AppConfig()

async func(s: state WorkerState, cfg: state AppConfig) {
    if s.done && cfg.verbose {
        io.printf("finished: %d iterations\n", s.count)
    }
}(workerSnap, cfgSnap)
```

No `effect` keyword. No dependency arrays. The `state T` parameter type is the
complete signal to the compiler.

**Rules:**

* `state T` is a valid parameter type only on `async`-invoked anonymous or named
  functions (§40).
* Each `state T` parameter generates an independent `.subscribe()` + `while
  true { .receive() }` loop at compile time.
* The parameter binding (e.g. `s`) is updated to the latest broadcast value on
  every iteration.
* The function body runs on the main thread event loop on every broadcast from
  any subscribed state.

---

## 47. Full Example: Thread Broadcasting to Main via State

```vertex
package main

import "std/io"

state WorkerState {
    count:   int32       = 0
    message: *const char = ""
    done:    bool        = false
}

// runs on its own OS thread
// only receives the setter — never touches the event loop
func worker(set: func(WorkerState)) {
    var i: int32 = 0
    while i < 5 {
        i = i + 1
        set(WorkerState{ count: i, message: "processing...", done: false })
    }
    set(WorkerState{ count: 5, message: "all done!", done: true })
}

func main() -> int {
    let (snap, setState) = WorkerState()

    io.printf("initial count: %d\n", snap.count)

    // thread broadcasts state changes — isolated, no event loop involvement
    thread worker(setState)

    // async effect — pass snap, compiler generates subscribe + while + receive
    // runs on main thread event loop, wakes on every broadcast
    async func(s: state WorkerState) {
        io.printf("count: %d  msg: %s\n", s.count, s.message)

        if s.done {
            io.printf("thread finished\n")
            runtime.exit(0)
        }
    }(snap)

    runtime.loop()
    return 0
}
```

**Data flow:**

```
thread worker()
    → setState(WorkerState{...})        // writes value, fans out via chan
        → async effect receives update  // compiler-generated receive()
            → body runs on main loop    // safe, no races, no locks
```

---

## 48. Architectural Philosophy: Why State Machines for `async`?

Vertex strictly rejects the Green Thread model for `async` in favor of
**Compile-Time State Machines** (Rust/C++ style).

### The Flaws of Green Threads

1. **Hidden Runtime:** Green threads require a massive bundled scheduler for
   preemptive context switching and timer queues.
2. **Stack Memory Bloat:** Every green thread needs a fake stack (2KB+ minimum).
   10,000 idle websocket connections = 20MB+ RAM.
3. **The UI Problem:** Graphical OS frameworks crash if UI updates happen off the
   Main Thread. Green thread schedulers hop between cores unpredictably.

### The Vertex Solution

When you apply `async`, the compiler shreds the function into a C `struct`
(holding local variables) and a `switch` statement.

- **Tiny Memory:** A state machine consumes only the exact bytes needed for its
  local variables (< 64 bytes typically), allowing millions of concurrent tasks
  with near-zero RAM footprint.
- **C-Native:** Uses the standard OS thread stack when executing, unwinds
  completely when yielding.
- **UI Perfect:** `async` tasks run cooperatively on the single Main Thread.
  When a network call or state broadcast arrives, the state machine resumes
  directly on the Main Thread — 100% safe for native UI updates.

---

## 49. Native Interface

```vertex
package windows_d3d11
build windows
import "windows/com/d3d11"

class C : c {
  func printf(fmt: ...*const char)
}

class IUnknown : d3d11 {
    func QueryInterface(obj: IUnknown, riid: *const void, ppv: *void) -> int32
    func AddRef(obj: IUnknown) -> uint32
    func Release(obj: IUnknown) -> uint32
}

class ID3D11Device : IUnknown {
    func CreateBuffer(
        d: ID3D11Device,
        desc: *const void,
        init: *const void,
        ppBuffer: **void) -> int32
    func CreateTexture2D(
        d: ID3D11Device,
        desc: *const void,
        init: *const void,
        ppTexture: **void) -> int32
}
```

---

## 50. Build Tags

```vertex
package mypackage
build amd64

package mypackage
build windows

package mypackage
build intrinsics_amd64
```

**Rules:**

* `build <tag>` is a file-level declaration that restricts the file to a specific
  build condition.
* Exactly one `build` tag may appear per file.
* `build` declarations must appear after the `package` declaration and before
  any `import` declarations.
* The recognised architecture tags are `amd64` and `arm64`. The compiler
  selects exactly one architecture tag per target.
* The recognised layer tags are `intrinsics`, `builtin`, and `core`. These
  control import access enforcement (§53).
* Arbitrary platform tags (e.g. `windows`) are valid and may be defined by
  the build system.
* A file with no `build` tag is compiled unconditionally on all targets.

---

## 51. Package Declarations

```vertex
package memory
package atomic
package windows_d3d11
```

**Rules:**

* `package <name>` declares the package identity of the file.
* The package name must be a valid identifier.
* Every source file must contain exactly one `package` declaration.
* The `package` declaration must appear after any `build` tags and before any
  `import` declarations.
* All files in the same directory must share the same package name.
* Package names have no impact on the binary — they are a compile-time namespace
  construct only.

---

## 52. Inline Assembly

`asm()` is valid only inside a `build intrinsics` function body. It is a
compile error anywhere else in the language.

**Void form — no return value:**

```vertex
func fence() {
    asm("mfence")
}
```

**Return form — maps output registers to the return type:**

```vertex
func load32(addr: *uint32) -> uint32 {
    return asm(
        "mov eax, [rdi]",
        "mfence",
        in("rdi") addr,
        out("eax")
    )
}
```

**Tuple return — multiple output-producing constraints:**

```vertex
func add32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "add eax, ecx",
        inout("eax") a,
        in("ecx") b,
        out("cf")
    )
}
```

**Operand declarations:**

```vertex
in("register") param          // register is loaded with param before execution
inout("register") param       // register is seeded with param on entry;
                              // its exit value contributes to the return
out("register")               // register's exit value contributes to the return;
                              // undefined on entry
clobber("reg", "reg", ...)    // registers are trashed — not inputs or outputs
```

**Special register tokens** — valid in `out` and `clobber` only:

| Token     | Meaning           |
|-----------|-------------------|
| `"cf"`    | carry flag        |
| `"zf"`    | zero flag         |
| `"sf"`    | sign flag         |
| `"of"`    | overflow flag     |
| `"flags"` | all condition flags |

**Rules:**

* Instruction strings are passed verbatim to the backend assembler. AMD64 uses
  Intel syntax (`dest, src`; no `%` or `$` prefixes). ARM64 uses standard
  AArch64 syntax (`dest, src1, src2`).
* A function body inside a `build intrinsics` package must consist of exactly
  one `asm()` expression. No other statements may appear alongside it.
* Output-producing constraints — `inout` and `out` — contribute to the return
  tuple in declaration order. `in` and `clobber` do not contribute to the return
  regardless of position.
* `inout` declares a register that is live both on entry and exit. It is
  self-contained: no separate `out` for the same register is permitted.
* The `in` + `clobber` pattern on the same register is valid only when an
  instruction both reads the register as input and unconditionally destroys it
  (e.g. `cmpxchg` consuming `eax`). The emitter converts this to a discarded
  inout in the backend.
* `in("xN") addr` paired with `out("wN")` is valid when the same physical
  register is used at different widths across the boundary (e.g. 64-bit address
  in, 32-bit result out on ARM64). Use `inout` when the width is identical.
* All `asm()` blocks are implicitly non-eliminatable — the backend never
  optimises across an `asm` boundary and never removes an `asm` block as dead
  code.
* `clobber` registers must not appear in `in`, `inout`, or `out`, except for
  the `in` + `clobber` pattern described above.
* Only packages tagged `build builtin` or `build core` may import
  `intrinsics/*`. Any other import of an intrinsics package is a hard compiler
  error.
* Two functions — `likely` and `unlikely` (§`intrinsics/hint`) — are
  compiler-resolved hints. They carry no `asm()` body; the backend emits branch
  weight metadata directly. Declaring a body for them is a compile error.

---

## 53. Compiler Testing

### 53.1 The `test` Qualifier

`test` is a function qualifier. It occupies the same position as the legacy
qualifier slot between the parameter list and the return arrow. Unlike
`async`/`thread`/`process`/`gpu` (which are now call-site sigils, §40), `test`
remains a declaration-site qualifier — test functions are auto-discovered by the
test runner and are never called directly from user code.

```vertex
package arithmetic_test
build test
import "arithmetic"

func test_literal()    test -> Expected(int32, "42") { return 42 }
func test_add()        test -> Expected(int32, "15") { return add(a: 10, b: 5) }
func test_comparison() test -> Expected(bool, "1")   { return 5 > 3 }
func test_no_crash()   test                          { square(n: 0) }
```

### 53.2 `Expected`

`Expected` is the return type annotation for test functions. It declares both the return type of the function and the exact string the test runner expects to capture from standard output (`stdout`).

```vertex
Expected(type, string_literal)
```

* **`type`**: The concrete return type of the test function. Must match the type of the value actually returned.
* **`string_literal`**: The exact string the function's output must match to pass the test.

### 53.3 Return Value Formatting

When a test function returns a value, the compiler automatically emits a `printf` call to write the formatted value to `stdout` before the process exits. The format is fixed:

| Return type | Auto-emitted format | `Expected` syntax for value `5` |
| --- | --- | --- |
| `int32` | `%d` | `Expected(int32, "5")` |
| `int64` | `%lld` | `Expected(int64, "5")` |
| `uint32` | `%u` | `Expected(uint32, "5")` |
| `float32` | `%f` | `Expected(float32, "5.000000")` |
| `bool` | `%d` | `Expected(bool, "1")` (true) / `Expected(bool, "0")` (false) |
| `string` | `%s` | `Expected(string, "hello")` |

*(Note: The boolean format maps to the C backend's integer representation.)*

### 53.4 `build test`

Test files are identified by the `build test` tag. The compiler excludes them from normal builds and compiles them into standalone executables only when running in test mode.

```vertex
package arithmetic_test
build test
import "arithmetic"

func test_add() test -> Expected(int32, "15") {
    return add(a: 10, b: 5)
}
```

**Testing Rules:**

* **Placement**: The `test` qualifier sits between the parameter list and `->`. A `test`-qualified function may declare no parameters.
* **Return Type**: The return type must be `Expected(type, string_literal)` or omitted. The `type` argument must exactly match the type of the returned value.
* **Implicit Passing**: Omitting `Expected` means the test passes if the function completes without crashing (no output is checked).
* **Auto-Printing**: Returning a value inside a test function causes that value to be auto-formatted and written to `stdout` before exiting.
* **Compile-Time Only**: `Expected` is a compile-time metadata annotation; it does not affect standard type checking.
* **File Scoping**: `test`-qualified functions are only valid in files tagged `build test`. Declaring a `test` function elsewhere is a compile error.

---

## Explicitly Out of Scope in 2.2

| Feature                                           | Status                                  |
|---------------------------------------------------|-----------------------------------------|
| Inheritance                                       | Removed                                 |
| String interpolation `\()`                        | Removed                                 |
| `_` parameter labels                              | Removed                                 |
| `self` as implicit keyword or reserved identifier | Removed                                 |
| `static` keyword                                  | Removed                                 |
| Methods inside structs or classes                 | Removed                                 |
| `mutating` keyword                                | Removed                                 |
| `mut` parameter/receiver keyword                  | Removed — replaced by `*T` pointer syntax |
| Protocols                                         | Removed                                 |
| Extensions                                        | Removed                                 |
| `try` / `throws` / `do-catch`                    | Removed                                 |
| Nested structs or classes                         | Removed                                 |
| `async`/`thread`/`process`/`gpu` as function qualifiers | Removed — replaced by call-site prefix sigils (§40) |
| `.await()` / `.spawn()` / `.fork()` / `.dispatch()` postfixes | Removed — replaced by prefix sigils (§40) |
| `.channel()` postfix construction                 | Removed — replaced by `{}` / `{cap: N}` brace initialization (§43.1) |
| Generic constraints (`where T:`)                  | Deferred                                |
| Closures                                          | §36                                     |
| Enums with associated values                      | Deferred                                |
| Access control                                    | Deferred                                |
| Pattern matching beyond `if let` and `switch`     | Deferred                                |
| Custom operators                                  | Deferred                                |
| `async let` / `TaskGroup` concurrency             | Deferred                                |
| `actor` keyword                                   | Deferred — see `state` (§45) for the broadcast-reactive alternative |
| Conditional build expressions                     | Deferred                                |
| Import aliasing                                   | Deferred                                |
| Mixed tuple element labels                        | Deferred                                |
| Tuple `for`-loop destructuring                    | Deferred                                |
| `inout` tuple parameters                          | Deferred                                |
| Tuple splat into function arguments               | Deferred                                |
| `Err` value binding in `if let` else branch       | Deferred                                |
| `weak` in manual class instances                  | Deferred                                |
| Labeled `break` / `continue`                      | Deferred                                |

---

## Summary of Changes from 2.1

* **Execution model rewritten**: `async`/`thread`/`process`/`gpu` are no longer
  function-declaration qualifiers with `.await()`/`.spawn()`/`.fork()`/`.dispatch()`
  postfixes. They are now mutually exclusive **prefix sigils** applied to a call
  expression (§39–§40).
* **`gpu` now supports grid/block control** via `gpu(blocks: n, threads: n)`
  (previously deferred).
* **Channels are now declared with brace literals** (`{}` / `{cap: N}`) instead
  of the `.channel()` / `.channel(size: n)` postfix intrinsic (§43.1).
* **New Channel Dichotomy** (§42): functions returning `-> T` are
  auto-channeled (single-return); functions returning `void` use explicit
  stream channels.
* **New `select` block** (§44) for zero-CPU multiplexing across channels —
  previously deferred, now specified alongside the existing polling pattern.
* **New `state` keyword and Async State Effects** (§45–§46): a broadcast
  reactive primitive built on `chan T`, with `state T` parameters on `async`
  functions auto-generating subscribe/loop/receive machinery.
* **Tuples** (§37) now documented as carrying over channels (`chan (T, bool)`)
  for value/validity-flag patterns used with `select`.
* The `test` qualifier (§53) is unaffected — it remains a declaration-site
  qualifier, distinct from the new call-site execution sigils.