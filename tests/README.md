# Vertex Language — Test Suite

Reference tests for the [Vertex language spec](https://github.com/vertex-language/spec).
The suite currently covers **~240 test functions across 47 files**, spanning all core
language features from literals through first-class functions.

---

## Getting Started

**Prerequisites:** Install the Vertex compiler (`vertex` ≥ 0.2.0).

```sh
git clone https://github.com/vertex-language/spec
cd spec/tests

GOPROXY=direct go install github.com/vertex-language/vertex@main
GOPROXY=direct go install github.com/vertex-language/vertex/cmd/vertex
vertex -test -dir .
```

To run a single section:

```sh
vertex -test -dir 06_control_flow
```

---

## Directory Layout

| # | Directory | What's tested |
|---|-----------|---------------|
| 01 | `01_literals` | Integer literals (decimal, binary `0b`, octal `0o`, hex `0x`, underscore separators), float literals (decimal and hex mantissa), `true`/`false`, `nil`, string, multiline string, `char` |
| 02 | `02_variables` | `let` (immutable) and `var` (mutable) declarations; zero values |
| 03 | `03_types` | All scalar types: `int8`, `int16`, `int32`/`int`, `int64`, `uint8`, `uint16`, `uint32`/`uint`, `uint64`, `float`, `float64`, `bool`, `char`, `string`, `void`/`()` |
| 04 | `04_type_conversion` | Explicit conversions (`float(i)`, `int(3.99)`, `int8(i)` etc.); truncation, narrowing/wrap-on-overflow, no implicit coercion |
| 05 | `05_operators` | Arithmetic (`+` `-` `*` `/` `%`), compound assignment, bitwise (`~` `&` `\|` `^` `<<` `>>`), overflow (`&+` `&-` `&*`), comparison, logical, range (`...` `..<`), ternary, nil-coalescing `??`, operator precedence |
| 06 | `06_control_flow` | `if`/`else if`/`else`, `switch` (multi-value cases, `fallthrough`, exhaustive enum switch), `while`, `for-in` (half-open and closed ranges, array iteration), `break`, `continue` |
| 07 | `07_functions` | Declaration, labelled call sites, pointer parameters (`*T`), address-of (`&`), auto-deref, multiple return values |
| 08 | `08_arrays` | Fixed arrays (`[T](n)`, `[T](repeating:count:)`), growable arrays (`[T]()`, `[T](capacity:)`); all methods: `push`/`pop`/`unshift`/`shift`, `indexOf`/`includes`/`find`/`findIndex`, `sort`/`reverse`/`fill`, `map`/`filter`/`slice`/`concat`, `forEach`; `defer .delete()` |
| 09 | `09_maps` | `map[K]V` type, brace literal syntax, subscript read (returns `T?`), key write, `nil` assignment removes key, `defer .delete()` |
| 10 | `10_optionals` | `T?` scalar and pointer optionals, `if let` unwrap, `??` nil-coalescing |
| 11 | `11_structs` | Struct declaration, `let`/`var` binding mutability, field access, assignment copies, nested structs, trailing-comma literals |
| 12 | `12_associated_functions` | Value receivers `(p: T)`, pointer receivers `(p: *T)`, auto-deref (`p.x` → `p->x`), compiler-inserted `&` at call site |
| 13 | `13_enums` | Basic enums, `int` raw values (auto-increment), `string` raw values (default to case name), `.rawValue`, `EnumType(rawValue:)` returns `T?`, exhaustive `switch` (no `default` required) |
| 14 | `14_classes` | Heap allocation, `init`/`deinit` lifecycle, `.delete()`, identity operators (`===` `!==`), ref counting via `.new()`, `weak let` non-owning references |
| 15 | `15_defer` | LIFO execution order, `defer func() { }()` multi-statement form, defer with early returns |
| 16 | `16_generics` | Generic functions `func f<T>`, generic structs `struct Box<T>`, type inference at call site |
| 17 | `17_tuples` | Tuple literals, labelled elements, destructuring, function return tuples, `()` as `void`, comparison up to 6 elements |
| 18 | `18_error_handling` | Optionals for absence (`T?`), tuple returns for caller-decided errors `(T, string?)`, `Result(T, E)` with `Result(Ok, v)`/`Result(Err, e)`, `if let`, `switch` on `Ok`/`Err`, `.try()` propagation |
| 19 | `19_first_class_functions` | Function type syntax `func(T) -> T`, anonymous functions, capture by value, writeback via pointer parameters, higher-order functions (`map`, `filter`, `sort` callbacks) |

---

## Planned Sections (not yet written)

| # | Directory | Planned coverage |
|---|-----------|-----------------|
| 20 | `20_async_await` | `async` qualifier, `.await()`, async channels |
| 21 | `21_threads` | `thread` qualifier, `.spawn()` / `.spawn(threads: n)`, shared-memory channels |
| 22 | `22_processes` | `process` qualifier, `.fork()` / `.fork(processes: n)`, IPC channels |
| 23 | `23_channels` | `T.channel()` / `T.channel(size: n)`, `.send()` / `.receive()`, `.trySend()` / `.tryReceive()`, `.close()` |
| 24 | `24_gpu` | `gpu` qualifier, `.dispatch()` / `.dispatch(gpu: n, mem: n)` |
| 25 | `25_anonymous_concurrent` | Inline `func(params) thread { }(args).spawn()` and equivalent forms for all qualifiers |

---

## Writing a Test

Test files carry the `build test` tag and declare test functions using the
`test` qualifier, which sits between the parameter list and the return arrow —
the same position as `async`, `thread`, `process`, and `gpu`.

```vertex
package arithmetic_test
build test

import "arithmetic"

func test_add()        test -> Expected("15")   { return add(a: 10, b: 5) }
func test_comparison() test -> Expected("true") { return 5 > 3 }
func test_no_crash()   test                     { square(n: 0) }
```

`Expected(string_literal)` is the return type annotation. The test runner
compares the function's formatted stdout output against that string. Omitting
`Expected` means the test passes if the function completes without crashing —
no output is checked.

Return values are auto-formatted before the runner captures them:

| Return type | Format   | `Expected` for value `5`  |
|-------------|----------|---------------------------|
| `int32`     | `%d`     | `"5"`                     |
| `int64`     | `%lld`   | `"5"`                     |
| `uint32`    | `%u`     | `"5"`                     |
| `float`     | `%f`     | `"5.000000"`              |
| `bool`      | `%d`     | `"1"` (true) / `"0"` (false) |
| `string`    | `%s`     | `"hello"`                 |

Test functions take no parameters. They are excluded from normal builds and
compiled into standalone executables only when running in test mode.

---

## Contributing

New test files follow the naming convention `NN_topic/description_test.vs`
with `package <topic>_test` and `build test` at the top. Sections 20–25 are
open for contribution once the corresponding spec chapters are finalised.