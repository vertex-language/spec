# Vertex Language Spec

**Vertex** is a forked and modified derivative of TypeScript (2026 base spec), which is itself
built on the ECMAScript specification.

## No semicolons

```vertex
if x {
    a()
} else {
    b()
}
```

## Function `func`

```vertex
func sample2(): void {

}
```

## Range `for`

```vertex
for i in 0..10 {}
```

## Iterator `for`

```vertex
for item in array {}
```

```vertex
for (name, score) in scores {
    print(name, score)
}
```

## Parenthesis-free control flow

```vertex
if x > 10 {
    doA()
} else if x > 0 {
    doB()
} else {
    doC()
}
```

```vertex
while x < 10 {
    x += 1
}
```

```vertex
for i in 0..10 {
    print(i)
}
```

```vertex
for item in array {
    print(item)
}
```

```vertex
switch x {
    case 0 {
        doZero()
    }
    case 1, 2, 3 {
        doSmall()
    }
    default {
        doOther()
    }
}
```

```vertex
if let value = maybeValue {
    use(value)
} else {
    return
}
```

## `struct`

```vertex
struct yourData {
    somedata: int
    constructor() {}
}
```

## `number` → `int`

```vertex
var x: int = 100
```

## `boolean` → `bool`

```vertex
var x: bool = true
```

## Destructors

```vertex
class FileHandle {
  constructor() {}
  destructor() {}
}
```

## Tuple types & destructuring

```vertex
func divide(a: int, b: int): (int, int) {
  return (a / b, a % b)
}
let (quotient, remainder) = divide(17, 5)
```

## `const` = compile-time only

```vertex
const x: int = 100
```

## Custom `use` directives

```vertex
use strict
use windows123
use something
```

## `var` / `let` semantics

`var` and `let` follow Swift's binding concept rather than JS's: the split is mutability, not scope. `var` declares a mutable binding, `let` declares an immutable one — both are block-scoped, and neither has JS's `var` hoisting/function-scoping baggage. Unlike JS's three-way `var`/`let`/`const` split, `vertex` only needs two keywords for bindings, since `const` is reserved separately for compile-time-only values (see above), not general immutability.

```vertex
var x = 10
x = 20          // OK — var is mutable

let y = 10
y = 20          // error — let is immutable, same as Swift's `let`
```

## Declaration decorators

```vertex
@packed123 struct Sample001 {}
@packed123 class Sample001 {}
@inline123 func sample001(): void {}
@align(64) struct Sample002 {}
```

## Parameter passing-mode operators

```vertex
func sample001(a: mutating Sample002): void {}
func sample001(a: readonly Sample002): void {}
```

## `kernel func` / `graph func`

```vertex
kernel func sample001(): void {}
graph func sample001(): void {}
```

## File-scoped `namespace`

```vertex
namespace main

func main(): int32 {}
```

```vertex
namespace something2

export func yourfunc(): void {}
```

## Go-form imports

```vertex
import "app/net/http"

import (
    "app/net/http"
    "std/io"
)

import (
    _   "app/drivers/sqlite"
    sysio "std/io"
)
```

```vertex
http.get(url)
```

## Struct declare — `declare module` / `declare struct`

```vertex
declare struct Sample001

declare module "sample001" {
  export func sample002(n: uint32): int32
}
```

## `enum` with typed backing and associated values

Extends TS's own `enum` rather than replacing it — same `:` type-annotation token used everywhere else in the grammar for the backing type, and a labeled parameter list (same shape as a function signature) for associated-value cases.

```vertex
enum StatusCode: int32 {
    OK = 200
    NotFound = 404
    ServerError = 500
}
```

```vertex
enum Shape {
    Circle(radius: float64)
    Rectangle(width: float64, height: float64)
    Point
}
```

```vertex
enum Option<T> {
    Some(value: T)
    None
}

enum Result<T, E> {
    Ok(value: T)
    Err(error: E)
}
```