# Vertex Compiler Testing Grammar

## Specification 1.0

---

## 1. The Problem

Standard unit testing frameworks share a foundational assumption: the compiler
they run on is already correct. This assumption is reasonable for mature
languages with decades of validation behind them. It is not reasonable when
building a new compiler from scratch.

When a new compiler is under active development, none of its control flow,
arithmetic, function calls, or variable handling can be taken as given. The
compiler has to prove each of those things works before anything built on top
of them can be trusted — including the test infrastructure itself.

This is the bootstrap problem. You cannot test a compiler using a framework
that depends on the compiler being correct.

---

## 2. How Other Languages Approach Testing

### 2.1 Go

Go's `testing` package is elegant and minimal. Test functions take a `*testing.T`
parameter, make assertions with `if` statements, and report failures by calling
methods on `t`.

```go
func TestAdd(t *testing.T) {
    cases := []struct {
        a, b int
        want int
    }{
        {10, 5, 15},
        {-1, 1, 0},
    }
    for _, c := range cases {
        got := Add(c.a, c.b)
        if got != c.want {
            t.Errorf("Add(%d, %d) = %d, want %d", c.a, c.b, got, c.want)
        }
    }
}
```

Every line of this test silently depends on the Go compiler being correct:

- The struct literal `[]struct{...}{{10, 5, 15}, ...}` assumes composite
  literals work.
- `for _, c := range cases` assumes for-range works.
- `if got != c.want` assumes `if` and `!=` work.
- `t.Errorf(...)` assumes method calls and variadic functions work.

For Go this is fine. The Go compiler has been validated for over a decade.
The framework authors were entitled to assume it. A new compiler is not in
that position. If `for-range` is broken in Vertex, every test that uses
`for-range` in its assertion logic fails — not because the code under test is
wrong, but because the test framework itself is broken.

### 2.2 Java / JUnit

```java
@Test
public void testAdd() {
    assertEquals(15, calculator.add(10, 5));
}
```

`assertEquals` is a Java method call. `@Test` is a Java annotation processed
by the JVM. The assertion mechanism is written in Java and compiled by the
same compiler that produced `calculator`. If the compiler's method dispatch is
broken, `assertEquals` itself may not execute correctly, and a passing test
tells you nothing.

### 2.3 The Shared Assumption

Both frameworks say: **trust the compiler, test the code.**

That is the correct stance once a compiler is proven. It is circular reasoning
when the compiler is what you are trying to prove.

---

## 3. The Vertex Approach — Prove the Compiler

Vertex inverts the relationship. Instead of writing test logic in Vertex and
trusting the compiler to execute it correctly, the test grammar is designed so
that:

- All assertion logic lives in the external Go test runner, which is trusted.
- Each Vertex test function is as structurally minimal as possible.
- One test proves exactly one compiler feature.
- Failure modes map directly to specific compiler stages.

The `test` function qualifier and the `Expected` return type are the two
grammar primitives that make this possible.

```vertex
func test_add() test -> Expected(stdout, "15") {
    return add(a: 10, b: 5)
}
```

The Vertex side of this test uses almost nothing:

- A variable declaration.
- A function call.
- A return statement.

The comparison `"15" == actual_output` never happens in Vertex. It happens in
Go. The Vertex program just computes and returns. The runner captures stdout
and does the rest.

---

## 4. Grammar

### 4.1 The `test` Qualifier

`test` is a function qualifier. It occupies the same position as `async`,
`thread`, `process`, and `gpu` — between the parameter list and the return
arrow.

```vertex
func test_literal()    test -> Expected(stdout, "42")   { return 42 }
func test_add()        test -> Expected(stdout, "15")   { return add(a: 10, b: 5) }
func test_comparison() test -> Expected(stdout, "true") { return 5 > 3 }
func test_no_crash()   test                             { square(n: 0) }
```

### 4.2 `Expected`

`Expected` is a two-argument return type declaration for test functions.

```vertex
Expected(Channel, string_literal)
```

| Argument        | Type           | Meaning                                      |
|-----------------|----------------|----------------------------------------------|
| `Channel`       | channel ident  | where the output is captured                 |
| `string_literal`| string literal | what the output must equal after formatting  |

Two channels are defined in 1.0:

| Channel    | Source                         |
|------------|--------------------------------|
| `stdout`   | standard output of the binary  |
| `exitCode` | process exit code as a string  |

`exitCode.Expected` is the only test primitive that does not depend on
`printf` being stable. It is valid even if stdout is completely broken.

```vertex
// does not require printf
func test_exits_clean() test -> Expected(exitCode, "0") {
    return 0
}
```

### 4.3 Return Value Formatting

When a test function returns a value, the compiler auto-emits a `printf` call
that writes the formatted value to stdout before the process exits. The format
is fixed and part of the spec — the test author knows exactly what string to
put in `Expected`.

| Return type | Auto-emitted format | `Expected` string for value 5   |
|-------------|---------------------|---------------------------------|
| `int32`     | `%d`                | `"5"`                           |
| `int64`     | `%lld`              | `"5"`                           |
| `uint32`    | `%u`                | `"5"`                           |
| `float`     | `%f`                | `"5.000000"`                    |
| `bool`      | `true` / `false`    | `"true"`                        |
| `string`    | `%s`                | `"hello"`                       |

### 4.4 `build test`

Test files are identified by the `build test` tag. The compiler excludes them
from normal builds and includes them only when running in test mode. All
`test`-qualified functions must appear in `build test` files.

```vertex
build test
package arithmetic_test
import "arithmetic"

func test_add() test -> Expected(stdout, "15") {
    return add(a: 10, b: 5)
}
```

### 4.5 Full Grammar Rules

- `test` is a function qualifier. It sits between the parameter list and `->`.
- A `test`-qualified function may declare no parameters.
- The return type is either `Expected(Channel, string_literal)` or omitted.
- Omitting `Expected` means the test passes if the function completes without
  crashing. No output is checked.
- `return value` inside a test function causes `value` to be auto-formatted
  and written to stdout before the process exits.
- The compiler infers the actual return type from the function body normally.
  `Expected` is a compile-time annotation only — it does not change type
  checking.
- `test`-qualified functions are auto-discovered by the test runner. They are
  never called directly from user code.
- `test`-qualified functions are only valid in files tagged `build test`.
  Declaring a `test` function in a non-test file is a compile error.

---

## 5. The Bootstrap Ladder

Because each test depends only on what has already been proven, tests are
written in order of compiler feature complexity. Each rung of the ladder only
uses features proven by the rungs below it.

```
── Stage 0 ─────────────────────────────────────────────────────
   Raw programs with explicit libc.printf and main().
   Proves: the binary runs, printf produces output, exit codes work.
   No test qualifier used yet.

── Stage 1 ─────────────────────────────────────────────────────
   test qualifier, Expected(exitCode), Expected(stdout) with literals.
   Proves: literals, return, the auto-printf formatting.

   func test_int_literal() test -> Expected(stdout, "42") {
       return 42
   }

── Stage 2 ─────────────────────────────────────────────────────
   Proves: arithmetic operators.
   Depends on: Stage 1 (return and stdout known good).

   func test_add() test -> Expected(stdout, "15") {
       return add(a: 10, b: 5)
   }

── Stage 3 ─────────────────────────────────────────────────────
   Proves: if / else branching.
   Depends on: Stage 2 (arithmetic known good for conditions).

   func test_if_true() test -> Expected(stdout, "yes") {
       let x: int32 = 10
       if x > 5 { return "yes" }
       return "no"
   }

── Stage 4 ─────────────────────────────────────────────────────
   Proves: while loops, for-in ranges.
   Depends on: Stage 3 (if known good for loop conditions).

   func test_while() test -> Expected(stdout, "5") {
       var i: int32 = 0
       while i < 5 { i += 1 }
       return i
   }

── Stage 5 ─────────────────────────────────────────────────────
   Proves: user-defined functions, recursion, multiple parameters.
   Depends on: Stage 3 (if known good for base cases).

── Stage 6 ─────────────────────────────────────────────────────
   Proves: structs, arrays, maps, classes.
   Depends on: Stages 1–5.

── Stage N ─────────────────────────────────────────────────────
   Once Stages 1–5 are proven, the compiler's own features can be
   used inside test function bodies without circular risk.
```

No stage borrows from an unproven stage. If Stage 3 tests fail, Stage 4 tests
are not run — they depend on `if` being correct and that has not been
established.

---

## 6. Failure Diagnostics

Because test functions are structurally minimal, every failure mode points to
a specific compiler stage. There is no framework code to blame.

```
func test_add() test -> Expected(stdout, "15") {
    return add(a: 10, b: 5)
}
```

| Symptom                        | Compiler stage implicated               |
|--------------------------------|-----------------------------------------|
| Compile error                  | Parser or type checker                  |
| Binary does not run / crashes  | Code generator or linker                |
| Output is empty                | `return` lowering or auto-printf broken |
| Output is wrong value          | Arithmetic code generation              |
| Output is correct but mangled  | `printf` format string emission         |

Compare this to a Go-style test failure where the same symptoms could originate
in the framework code, the test helpers, the standard library, or the code
under test. With the Vertex test grammar there is exactly one place to look.

---

## 7. Comparison Summary

|                          | Go / JUnit              | Vertex `test` qualifier       |
|--------------------------|-------------------------|-------------------------------|
| Assertion logic in       | the language under test | external Go runner (trusted)  |
| Depends on               | compiler being correct  | nothing beyond printf + return|
| Failure points to        | anywhere                | specific compiler stage        |
| Tests per file           | many                    | many                          |
| Control flow in tests    | full                    | only when the feature is proven|
| Framework language       | Go / Java               | Go (external)                 |
| Assumption               | compiler is flawless    | compiler is unproven           |

Go and Java say: the compiler is solved, test the code on top of it.
Vertex says: the compiler is the thing being tested, prove it from the ground up.

---

## 8. Out of Scope in 1.0

| Feature                              | Status    |
|--------------------------------------|-----------|
| `Expected(stderr, "...")`            | Deferred  |
| Parameterised / table-driven tests   | Deferred  |
| `compileError` qualifier             | Deferred  |
| `suite` grouping blocks              | Deferred  |
| `before` / `after` lifecycle hooks   | Deferred  |
| Multi-value `Expected` (tuples)      | Deferred  |
| `xfail` / `skip` markers            | Deferred  |
| Test timeout per function            | Deferred  |