# Vertex Language Grammar

## Specification 2.2 — Foundation

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

## 13. Range Operators

```vertex
0..5     // exclusive: 0,1,2,3,4
0..=5    // inclusive: 0,1,2,3,4,5
```

---

## 14. Nil-Coalescing

```vertex
a ?? b
```

---

## 15. Identity Operators (classes only)

```vertex
a === b
a !== b
```

---

## 16. Operator Precedence (high → low)

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
| Lowest  | `=` `+=` `-=` `*=` `/=` `%=`     |

---

## 17. If / Else / Else If

```vertex
if x > 0 {
} else if x < 0 {
} else {
}
```

---

## 18. Switch

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

## 19. Break and Continue

```vertex
for i in 0..<10 {
    if i % 2 == 0 { continue }
    if i == 7     { break }
}

var n = 0
while true {
    if n >= 5 { break }
    n += 1
}
```

---

## 20. Functions

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
increment(mut count)
```

---

## 21. While Loop

```vertex
var i = 0
while i < 5 {
    i += 1
}
```

---

## 22. For-In Loop

```vertex
for i in 0..5 {
    // 0,1,2,3,4
}

for i in 0..=5 {
    // 0,1,2,3,4,5
}

let nums = [1, 2, 3]
for n in nums {
}
```

---

## 23. Arrays

### 23.1 Fixed Arrays

```vertex
var buf:  [uint8; 1024]
var nums: [int32; 16]

var coords: [int32; 3] = [10, 20, 30]

let nums  = [1, 2, 3]
let flags: [uint8; 3] = [0xFF, 0x00, 0xAB]

let bytes: [uint8; 3] = [
    0xFF,
    0x00,
    0xAB,
]

let matrix: [[float32; 2]; 2] = [
    [0.0, 1.0],
    [1.0, 0.0],
]

let first = buf[0]
buf[0]    = 255
```

---

### 23.2 Dynamic Arrays

```vertex
var items:   [int32] = []
var players: [Player] = []
var buf:     [uint8] = []

var scores = [10, 20, 30]
var names: [string] = ["a", "b"]
```

---

### 23.3 Add / Remove

```vertex
items.push(42)
let last = items.pop()
```

---

### 23.4 Access

```vertex
let n    = items.length
let x    = items[0]
items[0] = 99
```

---

### 23.5 Struct Arrays

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

players.push(Player{
    id:       1,
    position: Vec2{x: 0.0, y: 0.0},
    health:   100,
})

let hp            = players[0].health
players[0].health = 50
```

---

## 24. Maps

```vertex
let somemap = {"a": 1, "b": 2}
let val = somemap["a"]

let typedMap: map<string, int32> = {"a": 1, "b": 2}

var config: map<string, int32> = {}

config["debug"]   = 1
config["verbose"] = 0
config["debug"]   = nil
```

---

## 25. Optionals

```vertex
var maybe: int32? = nil
maybe = 5
if let val = maybe {
}

var animal: Animal? = nil
if let a = animal { }
let result = animal ?? defaultAnimal
```

---

## 26. Structs

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

## 27. Associated Functions (Receiver Syntax)

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

## 28. Enums

### 28.1 Unit Variants

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

### 28.2 Tuple Variants (positional associated data)

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

### 28.3 Mixed Variants

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

### 28.4 Explicit Discriminants

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
func statusFromInt(n: int32) -> Status? {
    switch n {
    case 0: return .Inactive
    case 1: return .Active
    case 2: return .Pending
    default: return nil
    }
}
```

---

## 29. Classes

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

## 30. Defer

```vertex
defer func() { cleanup(a) }()
```

```vertex
defer cleanup(a)
defer cleanup(b)
```

## 31. Tuples

### 31.1 Literals

```vertex
let t = (1, "a")
let pair = (1, 2)
let single = (1,)          // trailing comma required for 1-element tuples
```

### 31.2 Type Annotations

```vertex
let t: (int32, string) = (1, "a")
let coords: (float32, float32, float32) = (0.0, 1.0, 0.0)
```

### 31.3 Positional Access

```vertex
let t = (1, "a")
let a = t.0
let b = t.1
```

### 31.4 Named Fields

```vertex
let t = (x: 1, y: "a")
let a = t.x
let b = t.y

let p: (x: int32, y: int32) = (x: 3, y: 4)
```

### 31.5 Destructuring

```vertex
let (a, b) = t

let (x: px, y: py) = p   // rename on destructure
```

### 31.6 Function Returns

```vertex
func minMax(nums: [int32]) -> (int32, int32) {
    return (nums[0], nums[0])
}

let (lo, hi) = minMax(nums)
```

### 31.7 Nested Tuples

```vertex
let t: ((int32, int32), string) = ((1, 2), "origin")
let inner = t.0.0
```

---

## 32. Import Declarations

```vertex
import "github.com/something"

import (
    "github.com/something"
    "github.com/something/else"
)
```

---

## 33. First-Class Function Types

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
```

---

## 34. Anonymous Functions

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
    f(mut n)          // n is already mut-bound — pass directly
}

var total = 0
run(mut total, func(n: mut int32) {
    n += 10           // total is now 10
})
```

Right — package comes first, then build tags. Here's the corrected section:

---

## 35. Package Declarations

```vertex
package main
package somepackage
package somepackage2
```

---

## 36. Build Tags

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

## 37. Error Handling

### 37.1 Convention

```vertex
func parseInt(s: string) -> (int32, string) {
    if s == "" { return (0, "empty string") }
    return (42, "")
}

func connect(host: string, port: uint16) -> ((), bool) {
    if host == "" { return ((), false) }
    return ((), true)
}
```

---

### 37.2 Optionals

```vertex
func findUser(id: int32) -> User? {
    if id < 0 { return nil }
    return User(id)
}

if let user = findUser(id: 1) { }
let name = findUser(id: -1) ?? defaultUser
```

---

### 37.3 Destructuring

```vertex
let (n, err) = parseInt(s: "42")
if err != "" {
    log.printf("failed: %s\n", err)
}
```

---

### 37.4 Propagate — `?`

```vertex
let n = parseInt(s: s)?
```

---

### 37.5 Happy Path — `if let`

```vertex
if let n = parseInt(s: "42") {
}
```

---

### 37.6 Both Paths — `else ->`

```vertex
if let n = parseInt(s: "42") {
} else -> err {
    log.printf("failed: %s\n", err)
}
```

---

### 37.7 Full Control — `switch`

```vertex
let (n, err) = parseInt(s: "42")
switch err {
case "":
default:
}
```

## 38. Compiler Testing

### 38.1 The `test` Qualifier

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

### 38.2 `Expected`

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

### 38.3 `Expected(error)` — Compile-Failure Tests

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

### 38.4 `build test`

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