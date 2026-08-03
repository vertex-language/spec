## Foundation

---

## 1. Literals

```vertex
42
1_000_000

0b101010
0o52
0x2A

0xFF
0xBadFace
0x0123_4567_89ab_cdef

3.14
1_000.000_1
1.25e2
1.25e-2
1.25E2

0xFp2
0xFp-2
0xC.3p0

true
false

nil

"hello"
"A"
'A'

// Multiline string
`
multi
line
`
```

`_` may appear between successive digits for readability. It may not lead a digit
run, trail one, or be doubled.

**There is no negative literal.** `-1000` is unary minus applied to the literal
`1000`, which matters in exactly one place: a context expecting a literal token —
a `ShapeList` (accel §2.2), a `VectorType`'s lane count, a `TupleIndex` — will not
accept one.

**There is no prefix-free octal.** `0600` is the decimal integer 600; write `0o600`.

`1.` is not a literal (the fractional part must be non-empty) and neither is `.25`
(there is no leading-dot form). The first of those is what makes `1..5` scan as a
range rather than a float followed by a dot.

`nil` is legal only for `typed_ptr T` (memory §13). There is no general `nil`;
absence is the error tuple (§35).

An interpreted string literal is delimited by double quotes and recognizes escapes;
a raw string literal is delimited by back quotes, recognizes none, and includes
every line terminator it spans. A string is UTF-8 bytes with a length and no NUL
terminator.

---

## 2. Variable Declarations

```vertex
let x = 10
var y = 20
```

A `let` binding is fixed after initialization; a `var` binding may be assigned
again, and is the form required by anything that takes exclusive access (§19) or
transfers (ownership §3).

The distinction is not about mutation of the *value* — it is about rebinding the
name. A `let`-bound class may still have its fields written through a method whose
receiver is `mut`, but the binding itself must be `var` for that call to be legal
(ownership §2).

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
let k: float32 = 3.14
let l: float64 = 3.14159265358979
let m: bool   = true
let n: string = "hello"
let o: string = `
multi
line
`
let p: char = 'A'
```

None of those initializers carries a cast, which is §6.1's untyped-literal rule at
work, not an exception to §6.

A declaration with a type and **no** initializer is `var`-only:

```vertex
var buf: [1024]uint8
var handler: func(int32)
```

`let` always takes an initializer. The initializer-free form is also how a zero value
of a type parameter or a class is named (§35.5, generics §6).

---

## 4. Type Aliases

```vertex
type size_t = uint64
```

An alias introduces a *distinct name* for a type, and the two are interchangeable.
Where the distinction matters is a type set: a bare `uint64` in a constraint admits
only `uint64` exactly, while `~uint64` admits `size_t` as well (generics §3.1).

A type alias is also the only place the keyword `abstract` is admissible
(abstract_interfaces §1), and it may take type parameters (`type Vec[T] = []T`).

---

## 4.1 `byte` — the Preferred Spelling for `uint8`

`byte` is an alias for `uint8`, not a distinct type. The two are interchangeable in
both directions with no cast, at every depth of composition.

```vertex
let b: byte = 0xFF
let b2: uint8 = b        // ok — no cast, either direction
let raw: []byte = [0xFF, 0x00, 0xAB]
let same: []uint8 = raw  // ok — same underlying type
```

Prefer `byte` when the value is raw storage and `uint8` when it is a small number.
`constraints.Unsigned` needs no `byte` row for the same reason: `~uint8` already
admits it (generics §4).

---

## 5. Variadic Parameters

```vertex
func log(prefix: string, msg: ...string) {
    for m in msg {
        print(prefix)
        print(m)
    }
}
```

A variadic parameter must be last, and there may be at most one. Inside the body it
is an ordinary iterable of the element type.

---

## 6. Numeric Type Conversion

There are no implicit numeric conversions between *values*. Every width or
signedness change is written with `as` (§6.1), including ones that cannot lose
information.

```vertex
let i: int     = 42
let f: float32 = i as float32
let i2: int    = 3.99 as int
let b: int8    = i as int8
```

That `i as float32` is required while `let k: float32 = 3.14` is not is the whole of
§6.1's distinction: `i` is a typed value, `3.14` is not yet.

---

## 6.1 Untyped Literals

A numeric literal has no type of its own until it lands somewhere. Where the
destination type is known, the literal takes it; where it is not, the literal falls
back to a default.

```vertex
let g: uint8 = 255           // literal takes uint8 from the annotation
let n = 255                  // no destination — defaults to int32
takesFloat(1)                // literal takes float32 from the parameter
let x = smaller(3, 5)        // generic: the literals' default fixes T = int32
```

| Literal form | Default when nothing fixes it |
| --- | --- |
| `int_lit` | `int32` |
| `float_lit` | `float64` |
| `char_lit` | `char` |
| `string_lit` | `string` |
| `true` / `false` | `bool` |

A destination type is an annotation, a parameter type, a field type, a return
position, or the element type of a container being built. Where one exists and the
literal's value does not fit it, that is a compile error, not a wraparound:
`let b: int8 = 200` is rejected.

This applies to *literals only*. The moment a value has a type — because it was
bound, returned, or read from a field — §6 governs, and a conversion is written.

```vertex
let n = 255                  // n: int32
let b: int8 = n              // error: no implicit conversion — write `n as int8`
```

---

## 6.2 Casting — `as`

`as` is the conversion form. The call spelling `float32(i)` is the constructor syntax
for a named type and is **not** available on the predeclared numeric types; write
`i as float32`.

```vertex
let small: int32 = 42
let wide = small as int64
let big  = small as uint64

let f: float64 = 3.99
let i = f as int32

let count: int32 = 7
let ratio = count as float64 / total as float64

let x = value as int32 as int64
```

`as` binds tighter than every binary operator and is left-associative, so
`count as float64 / total as float64` is two conversions and then a division, and
`value as int32 as int64` is two conversions. Its right operand is a `Type`, not an
expression, which is why it is not in the precedence table at §15.

`as` also converts an enum to its discriminant type (§26.4), a pointer to and from an
integer (memory §7), and an `abstract` handle to a `typed_ptr` where linkage permits
(memory §8). Two element-type families take the constructor spelling instead: the
tensor element types, where `bf16(val)` is the form (accel §2.4).

> Numbered §6.2 rather than §6.1 as in previous revisions; §6.1 is now the
> untyped-literal rule the rest of the corpus assumed and never stated.

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

Both operands must already be the same type — there is no promotion. Overflow on the
signed forms traps; §10 gives the wrapping alternatives.

---

## 8. Compound Assignment

```vertex
a += b
a -= b
a *= b
a /= b
a %= b
```

Compound assignment is a statement taking exactly one target and one value, and the
target binding must be `var`. There is no `++` or `--` anywhere in the language.

---

## 9. Bitwise Operators

```vertex
~a
a & b
a | b
a ^ b
a << b
a >> b
```

`~` is bitwise-NOT in an expression. Inside a constraint's type set it is
underlying-type instead (generics §3.1); the two never appear in the same position.

---

## 10. Overflow Operators

```vertex
a &+ b
a &- b
a &* b
```

These wrap instead of trapping. They exist so that a wrapping intent is legible at
the site rather than inferred from the absence of a check.

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

`==` and `!=` require a type satisfying `comparable` (generics §3.4). Two types
notably outside it: a lane predicate from a `vector` comparison is not a `bool`
(accel §3.3), and a `tensor` comparison yields a `tensor[bool, ...]` (accel §2.3).

---

## 12. Logical Operators

```vertex
!a
a && b
a || b
```

`&&` and `||` take `bool` operands only and short-circuit.

---

## 13. Ranges

```vertex
0..5                     // 0,1,2,3,4 — always exclusive
a..b                     // empty when a >= b
```

> There is no inclusive form. To cover the full domain of a small integer type,
> iterate a wider type: `for i in 0..256 { let b = i as uint8 }`

`..` is non-associative: `a..b..c` is a compile error, folded neither way.

A range is not a value with a type of its own. It appears in exactly three positions:
a `for`'s iterable (§21.1), a bracket position where it makes a slice (§21.5), and a
`switch` case (§21.6).

---

## 14. Identity Operators (classes only)

```vertex
a === b
a !== b
```

These compare object identity and are legal only on classes. `==` on a class compares
values; `===` asks whether two bindings name the same object. Neither applies to a
`typed_ptr`, where `==` already compares addresses (memory §5).

---

## 15. Operator Precedence (high → low)

| Level   | Operators                               |
|---------|-----------------------------------------|
| Highest | `<<` `>>`                               |
|         | `*` `/` `%` `&` `&*`                    |
|         | `+` `-` `\|` `^` `&+` `&-`              |
|         | `..`                                    |
|         | `==` `!=` `<` `>` `<=` `>=` `===` `!==` |
|         | `&&`                                    |
| Lowest  | `\|\|`                                  |

`as` binds tighter than every operator in this table (§6.2), and `&` as a unary
operator binds tighter than `.` — `&p.add(1)` is `(&p).add(1)` (memory §2).

`..` is **non-associative**; `a..b..c` is a compile error.

Assignment (`=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`) is a
statement, not an expression, so it has no precedence — and no `=` can appear inside
a condition anywhere in the language.

---

## 16. If / Else / Else If

```vertex
if x > 0 {
} else if x < 0 {
} else {
}
```

An `if` has no initializer clause. The two-statement error-checking idiom (§35.2) is
intentional: the call is one statement, the check is the next, and nothing is
compressed into the header.

A composite or map literal between the keyword and the block has its opening brace
read as the block's; parenthesize to disambiguate (§24).

---

## 17. Switch

```vertex
switch x {
case 0:
case 1, 2:
default:
}
```

```vertex
switch s {
case "hello":
case "world":
default:
}
```

```vertex
switch direction {
case .North:
case .South:
case .East:
case .West:
}
```

```vertex
switch x {
case 0:
    fallthrough
case 1:
default:
}
```

At most one `default` clause; cases do not fall through unless `fallthrough` says so.
A case may list several patterns separated by commas, and ranges are admissible in
case position (§21.6).

In a case, a leading `.` is **always** an enum pattern, never the enum shorthand of
§26.1 reached through an expression. The difference is not cosmetic: a pattern's
payload entries are binding names and are views into the payload, not copies (§26.2).

---

## 18. Break and Continue

```vertex
for i in 0..10 {
    if i % 2 == 0 { continue }
    if i == 7     { break }
}
```

There are no loop labels; `break` and `continue` apply to the innermost loop. Neither
is admissible in an `npu` body, where a data-dependent trip count has nothing to lower
to (accel §2.5).

---

## 19. Functions

```vertex
func add(a: int32, b: int32) -> int32 {
    return a + b
}

add(1, 2)
add(a: 1, b: 2)
```

Arguments may be positional or named. A named argument uses the parameter's declared
name; parameter names belong to declarations, not to types, so a `func` type names
parameter types only (§31).

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(count)          // bare — exclusive access needs no marker
```

```vertex
func archive(w: var Widget) {
    storage.push(var w)
}

var w = Widget(1)
archive(var w)            // TRANSFER — marked
archive(w)                // COPY — bare
```

> Call sites for `mut` parameters are always bare: exclusive access is checked through
> the signature and never spelled at the call. Call sites for `var` parameters are the
> opposite — the marker is what picks transfer over copy, and both are legal at the
> same call. See ownership.md §2 (`mut`) and §3 (`var`); this file only shows the
> call-site shape.

Omitting the result type is the void form. There is no `void` type name and no unit
type — a function that returns nothing writes no `->` at all, and a function that only
reports failure returns a bare `string` (§35.1).

A signature may carry at most one marker (`async`, `gpu`, `npu`, `test`). The marker
is part of the function's type and is checked at both the declaration and the call
(§31).

### 19.1 `main`

```vertex
package main

func main() {
}
```

`main` is an ordinary declaration in package `main`, taking no parameters and
returning nothing. It is the one non-`async` function where `await` is legal, acting
as the root reactor entry point (async §2.2).

---

## 20. While Loop

```vertex
var i = 0
while i < 5 {
    i += 1
}

// stepping and reversal are while loops — no range methods
var j = 100
while j > 0 {
    j -= 10
}

// no value to bind against — loop on an explicit exit check instead
while true {
    let job, err = queue.pop()
    if err != "" { break }
    run(job)
}
```

`while` is the only loop primitive; `for` (§21) is the iterating form built on top of
it. The third shape above is the corpus's standard drain loop and appears throughout
`channels.md` and `async.md`.

---

## 21. For-In Loop

One loop shape: `for` consumes an iterable value. Ranges, arrays, maps, and strings
are the iterables. There is no user-extensible iterator protocol.

### 21.1 Ranges

```vertex
for i in 0..5 {
}

for i in start..end {
}
```

### 21.2 Arrays

```vertex
let nums = [1, 2, 3]

for n in nums {              // shared access
}

for mut n in nums {          // exclusive access — mutate in place
    n *= 2
}

for i, n in nums {           // index + value
}

for var f in frames {        // consuming — moves elements out,
    q.submit(var f)          // container dead after the loop
}
```

The marker attaches to the binding because what transfers is each element, one per
iteration — not the container. `for f in var frames` is not the same statement written
differently; it parses, and is rejected.

The two binding forms do not combine: there is no `for mut i, n in nums`. It parses,
and is rejected.

### 21.3 Maps

```vertex
let config = {"debug": 1, "verbose": 0}

for k, v in config {         // key + value, order unspecified
}

for k in config.keys() {
}

for v in config.values() {
}
```

Iteration order is unspecified and must not be relied on.

### 21.4 Strings

```vertex
for c in "héllo" {           // c: char — Unicode scalars
}

for b in s.bytes() {         // b: byte — raw UTF-8
}
```

The default iterates scalars, not bytes, which is why the byte form is spelled
explicitly.

### 21.5 Slicing (ranges in bracket position)

```vertex
let head = buf[0..4]         // shared-access view {ptr, len}
let tail = items[n..items.length]
```

A slice is an index whose expression is a range; there is no separate slice syntax. A
slice is a view, not a copy — it borrows the backing storage and does not own it.

### 21.6 Switch (ranges in case position)

```vertex
switch code {
case 0..100:
case 100..200:
default:
}
```

---

## 22. Arrays

### 22.1 Fixed Arrays

```vertex
var buf:  [1024]uint8
var nums: [16]int32

var coords: [3]int32 = [10, 20, 30]

let nums  = [1, 2, 3]
let flags: [3]uint8 = [0xFF, 0x00, 0xAB]

let bytes: [3]uint8 = [
    0xFF,
    0x00,
    0xAB,
]

let matrix: [2][2]float32 = [
    [0.0, 1.0],
    [1.0, 0.0],
]

let first = buf[0]
buf[0]    = 255
```

A `[N]T` is a value: it lives where it is declared, and copying the binding copies
every element.

### 22.2 Dynamic Arrays

```vertex
var items:   []int32  = []
var players: []Player = []
var buf:     []byte   = []

var scores = [10, 20, 30]
var names: []string = ["a", "b"]
```

A `[]T` is an implicitly heap-resident container — the one deliberate exception to
ownership §0's stack-by-default rule, shared with `map[K]V` and `chan T`. It owns its
storage discipline, which is why an allocation failure inside one is a panic rather
than a boundary tuple: the reporting form belongs to `new`, the primitive these types
are built from (memory §11).

Copying a `[]T` binding deep-copies the payload; the `var` marker at a call site is
what makes it O(1) instead (ownership §11).

The empty literal `[]` carries no element type of its own, so it is legal only where
the type is already fixed — an annotated declaration, an argument, a field default, or
a returned value.

### 22.3 Add / Remove

```vertex
items.push(42)

let last, err = items.pop()
if err != "" {
    // array was empty
}
```

`push` takes an owning parameter, so a fat element transfers with the marker and
deep-copies without it: `items.push(var frame)` vs `items.push(frame)` (ownership §11).

`pop` returns a boundary tuple, because an empty array is an absence and absence goes
through the same channel as failure (§35.4).

### 22.4 Access

```vertex
let n    = items.length
let x    = items[0]          // bounds-checked; out of range panics
items[0] = 99
```

Subscripting is not the fallible form — an out-of-range index is a panic, not an error
tuple, because a bad constant index on a fixed array is a compile error and a bad
computed one is a bug rather than a condition. Check `.length` first where the index
is not known good.

`typed_ptr T` is the unchecked counterpart and deliberately does not share this
spelling: it uses `.at` and `.setAt` instead (memory §6).

### 22.5 Struct Arrays

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

var players: []Player = []

players.push(Player{
    id:       1,
    position: Vec2{x: 0.0, y: 0.0},
    health:   100,
})

let hp            = players[0].health
players[0].health = 50
```

---

## 23. Maps

```vertex
let somemap = {"a": 1, "b": 2}

let val, err = somemap["a"]
if err != "" {
    // no such key — `val` is the element type's zero value
}

let typedMap: map[string]int32 = {"a": 1, "b": 2}

var config: map[string]int32 = {}

config["debug"]   = 1
config["verbose"] = 0

config.remove("debug")
let n = config.length
```

A map read is a boundary tuple (§35) like any other lookup that may find nothing —
there is no one-value form and no `nil` to compare against. Deletion is
`.remove(key)`, a no-op on a key that isn't present.

Writing to a map is an ordinary assignment statement, so the right-hand side is an
owning position: `config[k] = var built` transfers.

A key type must satisfy `comparable` (generics §3.4). A map literal's keys are
arbitrary expressions, unlike a composite literal's, whose keys are field names (§24).

---

## 24. Structs

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

```vertex
let p = Point{
    x: 3,
    y: 4,
}
```

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

**A field list is newline-separated, one field per line — not a comma list.** Two
fields on one line do not parse. A field may carry a default, evaluated at
construction for any omitted field:

```vertex
struct Config {
    retries: int32  = 3
    verbose: bool   = false
}
```

**Literals in a statement header.** A composite or map literal between the keyword and
the block of an `if`, `while`, `for`, or `switch` has its opening brace read as the
block's. Parenthesize to disambiguate:

```vertex
if p == (Point{x: 1, y: 0}) {
}
```

The same ambiguity is why a bare composite or map literal is not admissible as an
expression statement.

---

## 25. Associated Functions (Receiver Syntax)

```vertex
func (p: Point) describe() {
    let n = p.x
}

func (p: mut Point) reset() {
    p.x = 0
    p.y = 0
}

var p = Point{x: 3, y: 4}
p.describe()
p.reset()
```

```vertex
class Animal {
    name: string
}

func (a: Animal) init(name: string) {
    a.name = name
}

func (a: mut Animal) rename(newName: string) {
    a.name = newName
}

var rex = Animal(name: "Rex")
rex.rename(newName: "Max")
```

A receiver that writes a field must say `mut`, and its binding must be `var` at the
call site. An `init` or `deinit` receiver is implicitly exclusive and is written bare,
which is why `init` above assigns `a.name` without a qualifier.

A receiver may also be `var` (consuming — ownership §5) or `shared`. A method may not
declare its own type parameters; everything it is generic over comes from the receiver
(generics §9).

`init` and `deinit` get no production of their own: they are ordinary method names
recognized by spelling in a receiver declaration.

---

## 26. Enums

### 26.1 Unit Variants

```vertex
enum Direction {
    North,
    South,
    East,
    West,
}

enum Permission {
    Read,
    Write,
    Execute,
}
```

```vertex
let d = Direction.North
let d2: Direction = .South

switch d {
case .North:
case .South:
case .East:
case .West:
}
```

The leading-dot shorthand is legal wherever the enum type is already fixed by context.
A variant list is comma-separated and may span lines — an enum body is the one
brace-delimited declaration body that is not terminator-significant.

### 26.2 Tuple Variants (positional associated data)

```vertex
enum Shape {
    Point,
    Circle(float32),
    Rectangle(float32, float32),
    Color(uint8, uint8, uint8),
}

enum Result {
    Ok(int32),
    Err(string),
}

enum Payload {
    Integer(int32),
    Floating(float64),
    Text(string),
}
```

```vertex
struct Size {
    width:  uint32
    height: uint32
}

struct MousePos {
    x: int32
    y: int32
}

enum Event {
    Quit,
    KeyPress(uint8),
    MouseClick(MousePos),
    Resize(Size),
}
```

```vertex
let s = Shape.Circle(1.5)
let r = Result.Ok(42)
let p: Payload = .Text("hello")
let e = Event.Resize(Size{ width: 1920, height: 1080 })
```

```vertex
switch s {
case .Point:
case .Circle(r):
case .Rectangle(w, h):
case .Color(r, g, b):
}

switch e {
case .Quit:
case .KeyPress(key):
case .MouseClick(pos):
case .Resize(size):
}
```

```vertex
switch s {
case .Rectangle(w, _):
case .Color(r, _, _):
default:
}
```

A pattern's payload entries are binding names, never expressions, and they are views
into the payload rather than copies.

> `Result` above is an ordinary user enum, not an error convention. Fallibility is the
> tuple in §35 — the language has no built-in `Result` or `Option`.

### 26.3 Mixed Variants

```vertex
enum Message {
    Quit,
    Move(int32, int32),
    Write(string),
    ChangeColor(uint8, uint8, uint8),
}

enum NetworkEvent {
    Connected,
    Disconnected,
    Error(string),
}
```

### 26.4 Explicit Discriminants

```vertex
enum Status : int32 {
    Inactive = 0,
    Active   = 1,
    Pending  = 2,
}

enum HttpMethod : uint8 {
    Get    = 0,
    Post,
    Put,
    Delete,
}

enum ErrorCode : uint16 {
    None    = 0,
    Timeout = 408,
    Denied  = 403,
    Missing = 404,
    Crash,
}
```

```vertex
let s   = Status.Active
let raw = s as int32

let code = ErrorCode.Missing as uint16
```

```vertex
func statusFromInt(n: int32) -> Status {
    switch n {
    case 0: return .Inactive
    case 1: return .Active
    case 2: return .Pending
    default: return .Inactive
    }
}
```

An unassigned variant continues from the previous one, which is why `Post` is 1 and
`Crash` is 405 above. A discriminant is legal only on a unit variant; an explicit
discriminant on a payload variant parses, and is rejected.

The conversion runs one way only: `s as int32` is available, and there is no
`n as Status`. `statusFromInt` above is the idiom, and it is deliberately explicit
about what an unrecognized value means.

---

## 27. Classes

```vertex
class Animal {
  name: string
}

func (a: Animal) init(name: string) {
  a.name = name
}

func (a: Animal) deinit() {
}

let a = Animal(name: "Rex")
```

A class is byte-for-byte identical in layout to a struct and differs only in its
member and method model. A class is constructed by calling an initializer —
`Animal(name: "Rex")` — never by a composite literal; `Animal{}` constructs nothing.
For a zero-valued class, declare one: `var zero: Animal` (§35.5).

**An initializer has no error channel.** It returns the type, not a boundary tuple, so
a construction that can fail is written as an ordinary function returning `(T, string)`
instead — the pattern `abstract_interfaces.md` §5 uses for foreign handles.

`deinit` runs when the value goes dead. Both `init` and `deinit` receivers are
implicitly exclusive (§25).

Like a struct, a class is stack-resident by default; `unique(...)` and `shared(...)`
are the only paths to the heap (ownership §0.1).

---

## 28. Defer

```vertex
defer func() { cleanup(a) }()
```

```vertex
defer cleanup(a)
defer cleanup(b)
```

`defer` takes a call and nothing else — not a block, not an assignment. Deferred calls
run in reverse order of registration when the enclosing function returns. The idiom
pairs an acquisition with its release at the point of acquisition:

```vertex
let buf, err = new[uint8](1024)
if err != "" {
    return
}
defer delete(buf)
```

---

## 29. Tuples

**Rule of thumb: parens build, bare commas unbuild.** Parens appear when a tuple is
*constructed* — a literal or a type annotation. The moment a tuple is being *pulled
apart* — a `let` destructure, or a `return` handing multiple values back — it is
written bare, as a comma-separated list, with no wrapping parens.

There is no empty tuple. `()` is not a type and not a value; a function with nothing
to return omits its result (§19).

### 29.1 Literals — parens construct

```vertex
let t = (1, "a")
let pair = (1, 2)
let single = (1,)          // trailing comma required for 1-element tuples
```

`(x)` is a parenthesized expression; `(x,)` is a one-element tuple.

### 29.2 Type Annotations — parens are the type's shape

```vertex
let t: (int32, string) = (1, "a")
let coords: (float32, float32, float32) = (0.0, 1.0, 0.0)
```

A parenthesized single type without a trailing comma is that type, not a 1-tuple:
`(int32)` is `int32`.

### 29.3 Positional Access

```vertex
let t = (1, "a")
let a = t.0
let b = t.1
```

A `.` followed by a digit is always positional access — there is no leading-dot float
literal for it to collide with. The index must be a plain decimal literal with no
underscores.

### 29.4 Named Fields (construction)

```vertex
let t = (x: 1, y: "a")
let a = t.x
let b = t.y

let p: (x: int32, y: int32) = (x: 3, y: 4)
```

### 29.5 Destructuring — bare, no parens

```vertex
let a, b = t              // pulls t apart into a, b

let px, py = p            // positional destructure; use p.x / p.y directly
                          // if you want field names preserved instead of
                          // renaming on destructure
```

### 29.6 Function Returns — bare, no parens

```vertex
func minMax(nums: []int32) -> (int32, int32) {
    return nums[0], nums[0]
}

let lo, hi = minMax(nums)
```

The `-> (int32, int32)` in the signature is a type annotation (§29.2, parens
required); the `return` statement inside is handing values back (§29.6, bare).

A call returning a tuple cannot be forwarded whole into a multi-slot return —
`return inner()` where `inner` yields `(T, string)` hands one tuple into two slots.
Destructure first (generics §9 has the worked case).

### 29.7 Nested Tuples — parens construct, same as any literal

```vertex
let t: ((int32, int32), string) = ((1, 2), "origin")
let inner = t.0.0
```

---

## 30. Import Declarations

```vertex
import "github.com/something"

import (
    "github.com/something"
    "github.com/something/else"
)
```

There is no aliasing form, no dot-import, and no blank import. The qualifier under
which an imported package's symbols are reached comes from that package's own
`package` clause; the path is a locator, not a name. All imports precede all
declarations.

That separation is why `import "dom"` can hold a `declare module "websocket"` block
and still be reached as `dom.WebSocket` (abstract_interfaces §0).

---

## 31. First-Class Function Types

```vertex
// variable holding a function
var double:    func(int32) -> int32
var predicate: func(int32) -> bool
var transform: func(string, int32) -> string

// void return — arrow omitted
var onFire: func(int32)

// function type as a parameter
func apply(values: []int32, f: func(int32) -> int32) -> []int32 {
    var out: []int32 = []
    for v in values {
        out.push(f(v))
    }
    return out
}

// function type as a return type
func makeAdder(n: int32) -> func(int32) -> int32 {
    return func(m: int32) -> int32 {
        return m + n
    }
}
```

A declaration with a type and no initializer is `var`; `let` always takes one
(`let double = func(n: int32) -> int32 { return n * 2 }`).

A `func` type names parameter types only — names belong to declarations, not to types
— so `func(int32) -> int32` and `func(n: int32) -> int32` are the same type. A marker
(`async`, `gpu`, `npu`) is part of the type and is checked at both the declaration and
the call.

`mut T` and `var T` are legal in a `func` type's parameter positions and nowhere else
in one: not as the result, not in a field, local, or type argument (§32).

A function type may not carry an `Expected` result (§36) — that form reaches the
grammar only through a declaration, which is what keeps
`var f: func() -> Expected(int32, "5")` out of the language syntactically.

---

## 32. Anonymous Functions

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

A function literal begins with all enclosing parse context cleared and re-establishes
it from its own marker. An inner body that awaits must therefore say `async` itself —
it does not inherit the enclosing function's marker (async §3).

Capture — value semantics:

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

Reading a captured binding is fine; writing one is not. A closure that captures
anything at all cannot cross a foreign boundary, even read-only
(abstract_interfaces §6).

Writeback via `mut` parameter:

```vertex
func run(n: mut int32, f: func(mut int32)) {
    f(n)              // n is already mut-bound — pass directly
}

var total = 0
run(total, func(n: mut int32) {
    n += 10           // total is now 10
})
```

---

## 33. Package Declarations

```vertex
package main
package somepackage
package somepackage2
```

The package clause is mandatory and is the first non-comment construct in a file. A
file may open with blank or comment-only lines.

---

## 34. Build Tags

```vertex
build linux
build windows
build darwin
```

```vertex
package somepackage
build linux
```

```vertex
package main
build windows

func platformInit() {
}
```

The build clause, if present, is the second construct, immediately after the package
clause. The recognized tags are `linux`, `windows`, `darwin`, `js`, `wasm`, and
`test`. An unrecognized tag is a compile error, never a silently excluded file.

The clause is optional in general, with two exceptions elsewhere: a file containing a
`declare` block requires one, since ABI linkage is derived from it
(abstract_interfaces §0), and an `Expected` result requires `build test` (§36.2).

---

## 35. Error Handling

### 35.1 Convention

Every fallible or possibly-absent value is returned as a tuple: the value, and a
string that is empty (`""`) on success. This is the only shape in the language for
"this might not have worked" — there is no optional type and no propagation operator;
see §29.6 for the bare tuple-return syntax this convention relies on.

```vertex
func parseInt(s: string) -> (int32, string) {
    if s == "" { return 0, "empty string" }
    return 42, ""
}

func findUser(id: int32) -> (User, string) {
    if id < 0 {
        var zero: User
        return zero, "invalid id"
    }
    return User(id: id), ""
}
```

**Nothing to return but the error.** A function whose only outcome is success or
failure returns a bare `string` — there is no value slot to fill, so there is no
tuple:

```vertex
func connect(host: string, port: uint16) -> string {
    if host == "" { return "empty host" }
    return ""
}
```

`var zero: User` is how the error path names a zero value of a class — a composite
literal (`User{}`) constructs a *struct*, and a class is constructed only by calling
an initializer (§27). For a struct return the literal is available and either
spelling works.

Two places sit outside this convention, both stated where they occur: a class
initializer has no error channel (§27), and a container's allocation failure panics
rather than reporting (§22.2).

### 35.2 Checking the Error — the only pattern

```vertex
let n, err = parseInt(s: "42")
if err != "" {
    return
}
// n is usable past this point
```

```vertex
let err = connect(host: "example.com", port: 443)
if err != "" {
    return
}
```

Every call site that can fail looks like this. The `if err != ""` line is identical
whether the call returns a tuple or a bare string; only the destructure on the left
differs. The happy path continues directly below the check; nothing is hidden behind
an operator.

### 35.3 Chaining Calls

```vertex
func loadModel(path: string) -> (Model, string) {
    var zero: Model

    let text, err = readFile(path)
    if err != "" {
        return zero, err
    }

    let config, err2 = parseConfig(text)
    if err2 != "" {
        return zero, err2
    }

    return Model(config: config), ""
}
```

Each step is a plain tuple destructure and a plain `if`. This does not get shorter as
call depth grows — that is deliberate. Every branch is visible in the text.

The error binding is fresh at each step (`err`, `err2`) because a `let` does not
rebind; declare `var err: string` up front and use plain assignment if the repetition
grates.

### 35.4 Absence Is Not a Special Case

A function that may find nothing uses the same shape a function that may fail uses:

```vertex
func findUser(id: int32) -> (User, string) {
    var zero: User
    if id < 0 { return zero, "not found" }
    return User(id: id), ""
}

let user, err = findUser(id: -1)
if err != "" {
    // handle "not found" exactly like any other error
}
```

This is why map reads (§23) and `pop` (§22.3) return tuples: absence and failure share
one channel.

The collapse has a known cost where a caller must distinguish the two — a channel
consumer needs "empty" and "closed" to mean different things, and `.tryReceive()`
gives it one string for both (channels §6).

### 35.5 Zero Values on the Error Path

When a function returns an error, the paired value is the type's zero value — `0`,
`""`, `false`, a zeroed struct, a zeroed class, or `nil` for a `typed_ptr T`
(memory §13) — never a partially-constructed value. Write it as `var zero: T` and
return that; this is the same spelling a generic body uses for the zero of a type
parameter (generics §6).

Callers must check the error string before trusting the first return value; the
compiler does not enforce this, matching the convention's philosophy of
explicit-over-automatic.

---

## 36. Compiler Testing

### 36.1 The `test` Qualifier

```vertex
package arithmetic_test
build test
import "arithmetic"

func test_literal()    test -> Expected(int32, "42") { return 42 }
func test_add()        test -> Expected(int32, "15") { return arithmetic.Add(a: 10, b: 5) }
func test_comparison() test -> Expected(bool, "1")   { return 5 > 3 }
func test_no_crash()   test                          { arithmetic.Square(n: 0) }
```

`test` is a function marker, like `async`, `gpu`, and `npu`; a signature carries at
most one, so a test cannot also be `async`.

`test` is the one contextual keyword with two roles — a build tag and a function
marker — and the two positions never overlap.

### 36.2 `Expected`

```vertex
Expected(type, string_literal)
```

| Return type | Auto-emitted format | `Expected` syntax for value `5` |
| --- | --- | --- |
| `int32`   | `%d`   | `Expected(int32, "5")` |
| `int64`   | `%lld` | `Expected(int64, "5")` |
| `uint32`  | `%u`   | `Expected(uint32, "5")` |
| `float32` | `%f`   | `Expected(float32, "5.000000")` |
| `bool`    | `%d`   | `Expected(bool, "1")` / `Expected(bool, "0")` |
| `string`  | `%s`   | `Expected(string, "hello")` |

An `Expected` result is admissible only on a `FunctionDecl` or `MethodDecl` — never in
a function type or a literal — and only in a file built under the `test` tag.

### 36.3 `Expected(error)` — Compile-Failure Tests

```vertex
func test_bad_add() test -> Expected(error) {
    return arithmetic.Add(a: 10, b: "5")
}

func test_bad_assign() test -> Expected(error) {
    let x: int32 = "hello"
}

func test_bad_cast() test -> Expected(error, "cannot convert string to int32") {
    let x: int32 = "hello" as int32
}

func test_bad_field() test -> Expected(error, "no field 'z' on Point") {
    let p = Point{x: 0, y: 0}
    let n = p.z
}
```

```vertex
Expected(error)
Expected(error, string_literal)
```

`error` here is an ordinary identifier recognized only inside this form; it is
unrelated to §35's error strings, which are runtime values. The bodies above are
expected *not* to compile — which is why `test_bad_assign` has no `return` despite
its declared result.

### 36.4 `build test`

```vertex
package arithmetic_test
build test
import "arithmetic"

func test_add() test -> Expected(int32, "15") {
    return arithmetic.Add(a: 10, b: 5)
}

func test_bad_add() test -> Expected(error) {
    return arithmetic.Add(a: 10, b: "5")
}
```