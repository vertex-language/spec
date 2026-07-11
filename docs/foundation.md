# Vertex Language Grammar

## Grammar - Foundation

---

## 1. Literals

```vertex
42
-1000
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
```

---

## 4. Type Aliases

```vertex
type size_t = uint64
```

---

## 5. Type Variadic Args

```vertex
func log(prefix: string, msg: ...string) {
    for m in msg {
        libc.printf("%s: %s\n", prefix, m)
    }
}
```

---

## 6. Numeric Type Conversion

```vertex
let i: int    = 42
let f: float32  = float32(i)
let i2: int   = int(3.99)
let b: int8   = int8(i)
```

---

## 6.1 Casting — `as`

```vertex
var opt: int32 = 1

let small: int32 = 42
let wide = small as int64
let big  = small as uint64

let f: float64 = 3.99
let i = f as int32

let count: int32 = 7
let ratio = count as float64 / total as float64

let x = value as int32 as int64
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
~a
a & b
a | b
a ^ b
a << b
a >> b
```

---

## 10. Overflow Operators

```vertex
a &+ b
a &- b
a &* b
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

## 13. Ranges

```vertex
0..5                     // 0,1,2,3,4 — always exclusive
a..b                     // empty when a >= b
```

> There is no inclusive form. To cover the full domain of a small integer type, iterate a wider type: `for i in 0..256 { let b = i as uint8 }`

---

## 14. Identity Operators (classes only)

```vertex
a === b
a !== b
```

---

## 15. Operator Precedence (high → low)

| Level   | Operators                         |
|---------|-----------------------------------|
| Highest | `<<` `>>`                         |
|         | `*` `/` `%` `&` `&*`              |
|         | `+` `-` `\|` `^` `&+` `&-`        |
|         | `..`                              |
|         | `==` `!=` `<` `>` `<=` `>=`       |
|         | `&&`                              |
|         | `\|\|`                            |
| Lowest  | `=` `+=` `-=` `*=` `/=` `%=`      |

---

## 16. If / Else / Else If

```vertex
if x > 0 {
} else if x < 0 {
} else {
}
```

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
case .north:
case .south:
case .east:
case .west:
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

---

## 18. Break and Continue

```vertex
for i in 0..10 {
    if i % 2 == 0 { continue }
    if i == 7     { break }
}
```

---

## 19. Functions

```vertex
func add(a: int32, b: int32) -> int32 {
    return a + b
}

add(1, 2)
add(a: 1, b: 2)
```

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(count)
```

> Call sites for `mut`- and `var`-typed parameters are always bare —
> never a keyword at the call site, whether the parameter is exclusive
> access or ownership-transferring. See ownership.md §2 (`mut`) and §3
> (`var`/`.transfer()`) for the full rules; this file only shows the
> call-site shape.

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
    let job, ok = queue.pop()
    if !ok { break }
    run(job)
}
```

---

## 21. For-In Loop

One loop shape: `for` consumes an iterable value. Ranges, arrays, maps, and strings are the iterables.

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

for n in nums {          // exclusive access — mutate in place
    n *= 2
}

for i, n in nums {           // index + value
}

for f in frames.transfer() {    // consuming — moves elements out,
    q.submit(f.transfer())      // container dead after the loop
}
```

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

### 21.4 Strings

```vertex
for c in "héllo" {           // c: char — Unicode scalars
}

for b in s.bytes() {         // b: uint8 — raw UTF-8
}
```

### 21.5 Slicing (ranges in bracket position)

```vertex
let head = buf[0..4]         // shared-access view {ptr, len}
let tail = items[n..items.length]
```

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

---

### 22.2 Dynamic Arrays

```vertex
var items:   []int32 = []
var players: []Player = []
var buf:     []uint8 = []

var scores = [10, 20, 30]
var names: []string = ["a", "b"]
```

---

### 22.3 Add / Remove

```vertex
items.push(42)
let last = items.pop()
```

---

### 22.4 Access

```vertex
let n    = items.length
let x    = items[0]
items[0] = 99
```

---

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
let val = somemap["a"]

let typedMap: map[string]int32 = {"a": 1, "b": 2}

var config: map[string]int32 = {}

config["debug"]   = 1
config["verbose"] = 0
config["debug"]   = nil
```

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

p.describe()
p.reset()
```

```vertex
func (a: Animal) rename(newName: string) {
    a.name = newName
}

let rex = Animal(name: "Rex")
rex.rename(newName: "Max")
```

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

---

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

---

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

---

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

---

## 28. Defer

```vertex
defer func() { cleanup(a) }()
```

```vertex
defer cleanup(a)
defer cleanup(b)
```

## 29. Tuples

**Rule of thumb: parens build, bare commas unbuild.** Parens appear
when a tuple is *constructed* — a literal or a type annotation. The
moment a tuple is being *pulled apart* — a `let` destructure, or a
`return` handing multiple values back — it is written bare, as a
comma-separated list, with no wrapping parens.

### 29.1 Literals — parens construct

```vertex
let t = (1, "a")
let pair = (1, 2)
let single = (1,)          // trailing comma required for 1-element tuples
```

### 29.2 Type Annotations — parens are the type's shape

```vertex
let t: (int32, string) = (1, "a")
let coords: (float32, float32, float32) = (0.0, 1.0, 0.0)
```

### 29.3 Positional Access

```vertex
let t = (1, "a")
let a = t.0
let b = t.1
```

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

let px, py = p             // positional destructure; use p.x / p.y directly
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

The `-> (int32, int32)` in the signature is a type annotation (§29.2,
parens required); the `return` statement inside is handing values
back (§29.6, bare).

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

---

## 31. First-Class Function Types

```vertex
// variable holding a function
let double:    func(int32) -> int32
let predicate: func(int32) -> bool
let transform: func(string, int32) -> string

// void return — arrow omitted
let onFire: func(int32)

// function type as a parameter
func apply(values: []int32, f: func(int32) -> int32) -> []int32 { }

// function type as a return type
func makeAdder(n: int32) -> func(int32) -> int32 { }
```

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

## 35. Error Handling

### 35.1 Convention

Every fallible or possibly-absent value is returned as a tuple: the
value, and a string that is empty (`""`) on success. This is the only
shape in the language for "this might not have worked" — there is no
optional type and no propagation operator; see §29.6 for the bare
tuple-return syntax this convention relies on.

```vertex
func parseInt(s: string) -> (int32, string) {
    if s == "" { return 0, "empty string" }
    return 42, ""
}

func findUser(id: int32) -> (User, string) {
    if id < 0 { return User{}, "invalid id" }
    return User(id), ""
}

func connect(host: string, port: uint16) -> ((), string) {
    if host == "" { return (), "empty host" }
    return (), ""
}
```

---

### 35.2 Checking the Error — the only pattern

```vertex
let n, err = parseInt(s: "42")
if err != "" {
    log.printf("failed: %s\n", err)
    return
}
// n is usable past this point
```

Every call site that can fail looks like this. The happy path
continues directly below the check; nothing is hidden behind an
operator.

---

### 35.3 Chaining Calls

```vertex
func loadModel(path: string) -> (Model, string) {
    let text, err = readFile(path)
    if err != "" {
        return Model{}, err
    }

    let config, err2 = parseConfig(text)
    if err2 != "" {
        return Model{}, err2
    }

    return Model(config), ""
}
```

Each step is a plain tuple destructure and a plain `if`. This does not
get shorter as call depth grows — that is deliberate. Every branch is
visible in the text.

---

### 35.4 Absence Is Not a Special Case

A function that may find nothing uses the same shape a function that
may fail uses:

```vertex
func findUser(id: int32) -> (User, string) {
    if id < 0 { return User{}, "not found" }
    return User(id), ""
}

let user, err = findUser(id: -1)
if err != "" {
    // handle "not found" exactly like any other error
}
```

---

### 35.5 Zero Values on the Error Path

When a function returns an error, the paired value is the type's zero
value (`0`, `""`, a zero-valued struct/class) — never a
partially-constructed value. Callers must check `err` before trusting
the first return value; the compiler does not enforce this, matching
the convention's philosophy of explicit-over-automatic.

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

---

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

---

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

---

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