# Vertex Language Grammar

## Specification 2.1

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
| `string`          | see §9     | let → rodata, var → heap |
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


## 5. Type Variadic Args

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

## 6. Numeric Type Conversion

All numeric conversions are explicit. There is no implicit coercion between
numeric types.

```vertex
let i: int    = 42
let f: float32  = float32(i)       // int → float32, always safe
let d: double = double(f)      // float32 → double, always safe
let i2: int   = int(3.99)      // truncates toward zero → 3
let b: int8   = int8(i)        // narrowing — wraps on overflow
```

**Rules:**

* Conversion syntax is `targetType(value)` — no cast keyword.
* No implicit numeric conversion at any point.
* float32-to-integer conversion truncates toward zero.
* Narrowing integer conversions wrap on overflow, identical to `&+`, `&-`, `&*`.
* Widening conversions (e.g. `int` → `double`) are always value-preserving.


## 6.1 Casting — `as`

The `as` operator performs explicit type conversion. It is used for numeric widening, pointer reinterpretation, and float-to-integer truncation.

**Vertex**
```vertex

// ── pointer → pointer (no-op at runtime) ─────────────────────────────────────
var opt: int32 = 1
libc.setsockopt(sfd, 1, 2, &opt as *const char, 4)

var buf: [uint8](256)
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

## 7. Arithmetic Operators

```vertex
a + b
a - b
a * b
a / b
a % b
-a
```

---

## 8. Compound Assignment

```vertex
a += b
a -= b
a *= b
a /= b
a %= b
```

---

## 9. Bitwise Operators

```vertex
~a        // NOT
a & b     // AND
a | b     // OR
a ^ b     // XOR
a << b    // left shift
a >> b    // right shift
```

---

## 10. Overflow Operators

```vertex
a &+ b    // overflow add
a &- b    // overflow subtract
a &* b    // overflow multiply
```

---

## 11. Comparison Operators

```vertex
a == b
a != b
a >  b
a <  b
a >= b
a <= b
```

---

## 12. Logical Operators

```vertex
!a
a && b
a || b
```

---

## 13. Range Operators

```vertex
0...5     // closed
0..<5     // half-open
```

---

## 14. Ternary Operator

```vertex
condition ? a : b
```

---

## 15. Nil-Coalescing

```vertex
a ?? b
```

---

## 16. Identity Operators (classes only)

```vertex
a === b
a !== b
```

---

## 17. Operator Precedence (high → low)

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

## 18. If / Else / Else If

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

## 19. Switch

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
* `break` may be used inside a case to exit the switch early (§20).
* `switch` may appear anywhere a statement is valid.

---

## 20. Break and Continue

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

## 21. Functions

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

**Function qualifiers:**

A qualifier sits between the parameter list and the return arrow. All qualifiers
are mutually exclusive.

```vertex
func fetchUser(id: int32) async -> User { }
func crunch(data: [float32]) thread -> [float32] { }
func isolated(data: [float32]) process -> [float32] { }
func vectorAdd(a: [float32], b: [float32]) gpu -> [float32] { }
```

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

## 22. While Loop

```vertex
var i = 0
while i < 5 {
    i += 1
}
```

---

## 23. For-In Loop

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
* `break` and `continue` are valid inside any `for-in` body (§20).

---

## 24. Arrays

### 24.1 Fixed Arrays

Fixed arrays are stack-allocated with a size known at compile time.

```vertex
// zero-filled, fixed size — short form (zero implied)
var buf  = [uint8](1024)
var nums = [int32](5)

// zero-filled, fixed size — long form
var buf  = [uint8](repeating: 0, count: 1024)
var nums = [int32](repeating: 0, count: 5)

// non-zero fill — long form required
var mask = [uint8](repeating: 0xFF, count: 64)

// literal
let flags = [0xFF, 0x00, 0xAB]
let typed: [uint8] = [1, 2, 3]

// trailing comma — valid in multi-line literals
let bytes: [uint8] = [
    0xFF,
    0x00,
    0xAB,
]

// nested (multidimensional)
let matrix = [[1, 2], [3, 4]]
let grid: [[float32]] = [
    [0.0, 1.0],
    [1.0, 0.0],
]

// read / write
let first = nums[0]
nums[0] = 99
```

**Rules:**

* `[T](n)` allocates `n` elements of type `T`, all zero-filled. Prefer this form
  when the fill value is zero.
* `[T](repeating: v, count: n)` allocates `n` elements all set to `v`. Required
  when the fill value is not zero.
* Size must be a compile-time integer literal.
* Subscript read is valid on both `let` and `var` bindings.
* Subscript write requires the array binding to be `var`.
* Index bounds are not checked at compile time — out-of-bounds is a runtime error.
* No `.delete()` is needed — fixed arrays are stack-allocated and freed automatically.

---

### 24.2 Growable Arrays

Growable arrays are heap-allocated and must be freed with `.delete()`.

```vertex
// empty
var items = [int32]()
defer items.delete()

// pre-allocated capacity
var items = [int32](capacity: 64)
defer items.delete()
```

**Rules:**

* `[T]()` creates an empty growable array.
* `[T](capacity: n)` pre-allocates `n` slots without setting length.
* The caller is responsible for calling `.delete()` — failing to do so is a
  memory leak.
* `defer items.delete()` is the recommended pattern.

---

### 24.3 Add / Remove

```vertex
items.push(42)            // add to end
items.unshift(0)          // add to front

let last  = items.pop()   // remove from end,   returns T?
let first = items.shift() // remove from front, returns T?
```

**Rules:**

* `push` and `unshift` grow the array automatically.
* `pop` and `shift` return `T?` — `nil` if the array is empty.

---

### 24.4 Access

```vertex
let n    = items.length  // element count
let x    = items[0]      // subscript read
items[0] = 99            // subscript write
```

---

### 24.5 Search

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

### 24.6 In-Place Mutation

These methods mutate the array without allocating — no `.delete()` needed on
the result.

```vertex
items.sort(func(a: int32, b: int32) -> int32 {
    return a - b
})

items.reverse()

items.fill(0)
items.fill(0, from: 1, to: 3)
```

---

### 24.7 Methods That Return a New Array

These methods allocate a new array — the caller must call `.delete()` on the
result.

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

### 24.8 Iteration

```vertex
items.forEach(func(x: int32) {
    // process each element
})
```

---

### 24.9 Struct Arrays

Structs are copied by value on push — consistent with Vertex value semantics.

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

var players = [Player]()
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

### 24.10 Memory Rules

| Method                                              | Allocates | Action required         |
|-----------------------------------------------------|-----------|-------------------------|
| `push` `unshift` `fill` `sort` `reverse`            | no        | nothing                 |
| `pop` `shift`                                       | no        | nothing                 |
| `map` `filter` `slice` `concat`                     | yes       | `defer result.delete()` |
| construction `[T]()` `[T](capacity:)`               | yes       | `defer items.delete()`  |

---

Renaming them to "Maps" is a great call. It aligns perfectly with the `map[K]V` keyword we just introduced and is generally a more precise term for this data structure in systems-level languages like Vertex.

Here is the finalized **§25. Maps** section for your grammar document.

---

## 25. Maps

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

## 26. Optionals

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

## 27. Structs

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

## 28. Associated Functions (Receiver Syntax)

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

## 29. Enums

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

## 30. Classes

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

## 30.1 Reference Counting — `.new()`

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

## 31. Defer

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

## 32. Generics (unconstrained)

```vertex
func identity<T>(value: T) -> T {
    return value
}

struct Box<T> {
    value: T
}

let b      = Box{value: 42}
let result = identity(value: "hello")
```

---

## 33. Import Declarations

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

## 34. First-Class Function Types

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
let result = double(21)
```

**Rules:**

* Function type syntax is `func(ParamTypes) -> ReturnType`.
* When the return type is `void`, the arrow and return type are omitted:
  `func(int32)`.
* `*T` in a function type signature indicates a pointer parameter — the same
  rules as pointer parameters in named functions (§21) apply.
* Function types are value types — assignment copies the callable reference.
* Parameter names are not part of the type — only the types matter.

---

## 35. Anonymous Functions

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
  (§21) — capture alone cannot produce writeback.
* Pointer parameters (`*T`) inside an anonymous function follow the same rules as
  in named functions (§21).
* `return` inside an anonymous function returns from the anonymous function, not
  the enclosing function.
* Anonymous functions may not refer to themselves by name — they are not
  recursive. Recursion requires a named function.
* Anonymous functions are valid anywhere an expression is valid.
* The inferred type of an anonymous function is `func(ParamTypes) -> ReturnType`
  (§34).

---

## 35.1 Anonymous Concurrent Functions

An anonymous function may carry an execution qualifier between its parameter
list and body. The qualifier position is identical to named functions — no new
rule is introduced.

```vertex
// async
func(params) async -> ReturnType { body }(args).await()

// thread
func(params) thread -> ReturnType { body }(args).spawn()
func(params) thread -> ReturnType { body }(args).spawn(threads: n)

// process
func(params) process -> ReturnType { body }(args).fork()
func(params) process -> ReturnType { body }(args).fork(processes: n)

// gpu — results via .dispatch() only, no chan
func(params) gpu -> ReturnType { body }(args).dispatch()
func(params) gpu -> ReturnType { body }(args).dispatch(gpu: n, mem: n)
```

**Examples:**

```vertex
// thread — inline parallel workload
let results = float32.channel(size: 64)

func(data: [float32], out: chan float32) thread {
    for chunk in data {
        out.send(process(chunk))
    }
    out.close()
}(dataset, results).spawn()

// process — isolated compute feeding a channel
func(data: [float32], out: chan float32) process {
    for chunk in data {
        out.send(heavyCompute(chunk))
    }
    out.close()
}(dataset, results).fork()

// async — inline async task
let user = func(id: int32) async -> User {
    return fetchUser(id: id)
}(userId).await()

// gpu — inline kernel dispatch
let output = func(a: [float32], b: [float32]) gpu -> [float32] {
    return vectorAdd(a: a, b: b)
}(x, y).dispatch()
```

**Qualifier and postfix pairing:**

| Qualifier | Postfix                                     | `chan` valid |
|-----------|---------------------------------------------|-------------|
| `async`   | `.await()`                                  | yes         |
| `thread`  | `.spawn()` / `.spawn(threads: n)`           | yes         |
| `process` | `.fork()` / `.fork(processes: n)`           | yes         |
| `gpu`     | `.dispatch()` / `.dispatch(gpu: n, mem: n)` | no          |

**Rules:**

* The qualifier sits between the parameter list and the return arrow — identical
  to named functions.
* The trailing `(args)` is the call site — arguments are passed explicitly,
  not captured.
* The execution postfix must match the qualifier.
* All rules from §36, §39, §40, and §41 apply — the anonymous form changes
  nothing about execution semantics.
* Values from the enclosing scope are captured by value at creation (§35).
* To pass mutable state, use explicit pointer parameters — capture alone cannot
  produce writeback.
* `chan` parameters are valid in `async`, `thread`, and `process` functions only
  — passing a `chan` to a `gpu` function is a compile error.
* GPU functions communicate exclusively through their `.dispatch()` return value.

---

## 36. Async / Await

```vertex
func fetchUser(id: int32) async -> User {
    // body
}

let user   = fetchUser(id: 1).await()
let result = fetchUser(id: 1).await().name
```

**Rules:**

* `async` is written between the parameter list and the return arrow.
* A function with no return value may omit the return arrow: `func f(...) async { }`.
* `.await()` may only appear inside an `async` function body.
* Multiple `.await()` calls may appear in the same function body.

---

## 37. Tuples

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

**Function return:**

```vertex
func minMax(values: [int32]) -> (min: int32, max: int32) {
    return (0, 100)
}

let (lo, hi) = minMax(values: [3, 1, 4])
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

## 39. GPU Kernels

```vertex
func vectorAdd(a: [float32], b: [float32]) gpu -> [float32] {
    // body
    return result
}

let result = vectorAdd(a: x, b: y).dispatch()
let result = vectorAdd(a: x, b: y).dispatch(gpu: 0, mem: 256)
```

**Rules:**

* `gpu` is written between the parameter list and the return arrow.
* `.dispatch()` returns the kernel result directly.
* `.dispatch(gpu: n, mem: n)` selects a specific device and memory allocation.

---

## 40. Threads

```vertex
func crunchData(data: [float32]) thread -> [float32] {
    // runs in a thread, shared memory
}

let result = crunchData(data: x).spawn()
let result = crunchData(data: x).spawn(threads: 4)
```

**Rules:**

* `thread` is written between the parameter list and the return arrow.
* Threads share memory with the caller — passing data is zero-copy.
* `.spawn(threads: n)` spawns exactly n threads.

---

## 41. Processes

```vertex
func isolatedWork(data: [float32]) process -> [float32] {
    // runs in a separate process, full memory isolation
}

let result = isolatedWork(data: x).fork()
let result = isolatedWork(data: x).fork(processes: 4)
```

**Rules:**

* `process` is written between the parameter list and the return arrow.
* Processes have fully isolated memory — data is copied across the boundary.
* `.fork(processes: n)` forks exactly n processes.

---

## 42. Channels

`.channel()` is a type-level postfix intrinsic. It constructs a channel that
carries values of the receiver type. `chan` is the type modifier used in
annotations and parameter lists.

```vertex
// unbuffered — blocks sender until receiver is ready
let ch = string.channel()

// buffered — blocks sender only when buffer is full
let ch = string.channel(size: 32)

// annotated binding — type is inferred from construction, annotation optional
let ch: chan string = string.channel(size: 32)

// parameter annotation
func renderLoop(ch: chan rtp.Packet, ctx: canvas.Context) thread { }
```

**Operations — blocking:**

```vertex
ch.send(value)          // waits if full or no receiver ready
let val = ch.receive()  // waits until a value is available
ch.close()
```

**Operations — non-blocking:**

```vertex
let ok  = ch.trySend(value)  // bool — false if full or no receiver ready
let val = ch.tryReceive()    // T?   — nil if channel is empty
```

**Runtime transport by context:**

| Context   | Transport                        |
|-----------|----------------------------------|
| `async`   | shared memory, non-blocking      |
| `thread`  | shared memory, lightweight       |
| `process` | ring buffer, high-speed IPC      |

**Rules:**

* `.channel()` is only valid on type names, not instances.
* `size` must be a compile-time integer literal greater than zero.
* Omitting `size` produces an unbuffered channel.
* `chan` is the type modifier for annotations and parameter lists.
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

**Operation summary:**

| Method          | Blocking | Returns | Behaviour                          |
|-----------------|----------|---------|------------------------------------|
| `.send(value)`  | yes      | `void`  | waits until value is accepted      |
| `.receive()`    | yes      | `T`     | waits until value is available     |
| `.trySend()`    | no       | `bool`  | false if full or no receiver ready |
| `.tryReceive()` | no       | `T?`    | nil if channel is empty            |
| `.close()`      | no       | `void`  | always completes immediately       |

---

## 43. Postfix Execution Model — Summary

| Keyword   | Postfix                                     | Meaning                      |
|-----------|---------------------------------------------|------------------------------|
| `async`   | `.await()`                                  | suspend until done           |
| `thread`  | `.spawn()` / `.spawn(threads: n)`           | shared memory parallel       |
| `process` | `.fork()` / `.fork(processes: n)`           | isolated memory parallel     |
| `gpu`     | `.dispatch()` / `.dispatch(gpu: n, mem: n)` | gpu device execution         |
| —         | `.channel()`                                | construct unbuffered channel |
| —         | `.channel(size: n)`                         | construct buffered channel   |
| —         | `.new()`                                    | opt class into ref counting  |
| —         | `.delete()`                                 | manually free class instance |
| —         | `.try()`                                    | propagate Result error       |

---


## 44. Native Interface

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

## 45. Build Tags

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
  control import access enforcement (§46).
* Arbitrary platform tags (e.g. `windows`) are valid and may be defined by
  the build system.
* A file with no `build` tag is compiled unconditionally on all targets.
build intrinsics_amd64

---

## 46. Package Declarations

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

## 47. Inline Assembly

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

### 48. Compiler Testing

#### 48.1 The `test` Qualifier

`test` is a function qualifier. It occupies the same position as `async`, `thread`, `process`, and `gpu`—between the parameter list and the return arrow. Test functions are auto-discovered by the test runner and are never called directly from user code.

```vertex
package arithmetic_test
build test
import "arithmetic"

func test_literal()    test -> Expected(int32, "42") { return 42 }
func test_add()        test -> Expected(int32, "15") { return add(a: 10, b: 5) }
func test_comparison() test -> Expected(bool, "1")   { return 5 > 3 }
func test_no_crash()   test                          { square(n: 0) }
```

#### 48.2 `Expected`

`Expected` is the return type annotation for test functions. It declares both the return type of the function and the exact string the test runner expects to capture from standard output (`stdout`).

```vertex
Expected(type, string_literal)
```

* **`type`**: The concrete return type of the test function. Must match the type of the value actually returned.
* **`string_literal`**: The exact string the function's output must match to pass the test.

#### 48.3 Return Value Formatting

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

#### 48.4 `build test`

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

## Explicitly Out of Scope in 2.1

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
| Generic constraints (`where T:`)                  | Deferred                                |
| Closures                                          | §35                                     |
| Enums with associated values                      | Deferred                                |
| Access control                                    | Deferred                                |
| Pattern matching beyond `if let` and `switch`     | Deferred                                |
| Custom operators                                  | Deferred                                |
| `async let` / `TaskGroup` concurrency             | Deferred                                |
| `actor` keyword                                   | Deferred                                |
| Conditional build expressions                     | Deferred                                |
| Import aliasing                                   | Deferred                                |
| Mixed tuple element labels                        | Deferred                                |
| Tuple `for`-loop destructuring                    | Deferred                                |
| `inout` tuple parameters                          | Deferred                                |
| Tuple splat into function arguments               | Deferred                                |
| `Err` value binding in `if let` else branch       | Deferred                                |
| `select` over multiple channels                   | Deferred                                |
| `weak` in manual class instances                  | Deferred                                |
| GPU grid/block control                            | Deferred                                |
| Labeled `break` / `continue`                      | Deferred                                |