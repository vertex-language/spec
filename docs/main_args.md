## 49. Entry Point and the `os` Package

The entry point is `func main()` — no parameters, no return value. Process arguments and environment are accessed through the `os` package, identical in spirit to Go's `os` package.

---

### 49.1 Entry Point

```vertex
package main

func main() {
    // program starts here
}
```

---

### 49.2 Process Arguments — `os.args`

`os.args` is a `[string]` populated by the runtime before `main` is called. `os.args[0]` is always the program name. The array is runtime-owned — `.delete()` must not be called on it.

```vertex
package main
import "os"

func main() {
    if os.args.length < 2 {
        libc.printf("usage: %s <file>\n", os.args[0])
        os.exit(1)
    }

    let file = os.args[1]
    libc.printf("opening: %s\n", file)
}
```

**Iterating all arguments:**

```vertex
for arg in os.args {
    libc.printf("%s\n", arg)
}
```

**Skipping the program name — equivalent to Go's `os.Args[1:]`:**

```vertex
for i in 1..<os.args.length {
    libc.printf("arg %d: %s\n", i, os.args[i])
}
```

**As a slice — equivalent to Go's `os.Args[1:]` but heap-allocated:**

```vertex
var rest = os.args.slice(1, os.args.length)
defer rest.delete()
```

**Flag lookup:**

```vertex
let verbose = os.args.includes("--verbose")

let idx = os.args.indexOf("--output")
if idx != -1 && idx + 1 < os.args.length {
    let out = os.args[idx + 1]
    libc.printf("output: %s\n", out)
}
```

---

### 49.3 Environment Variables

```vertex
let home = os.env("HOME")           // string? — nil if not set

if let h = home {
    libc.printf("home dir: %s\n", h)
}

let port = os.env("PORT") ?? "8080" // default via nil-coalescing

// all env vars as "KEY=VALUE" pairs — heap-allocated, caller must delete
let environ = os.environ()
defer environ.delete()

for pair in environ {
    libc.printf("%s\n", pair)
}
```

---

### 49.4 Exit — `os.exit`

```vertex
os.exit(0)    // success
os.exit(1)    // failure
```

`os.exit` terminates the process immediately — **no deferred calls run**. Prefer a natural return from `main` when cleanup matters.

---

### 49.5 `os` Package Summary

| Symbol | Type | Notes |
|---|---|---|
| `os.args` | `[string]` | runtime-owned — no `.delete()`, no mutation |
| `os.args[0]` | `string` | program name |
| `os.args.length` | `int32` | total count including `args[0]` |
| `os.env(key)` | `string?` | `nil` if key absent |
| `os.environ()` | `[string]` | all vars as `"KEY=VALUE"` — caller must `.delete()` |
| `os.exit(code)` | `void` | terminates immediately, skips all defers |

---

**Rules:**

* `main` takes no parameters and returns no value — it may not carry a qualifier (`async`, `thread`, `process`, `gpu`).
* `os.args` is runtime-owned. Calling `.delete()`, `.push()`, `.pop()`, `.unshift()`, or `.shift()` on it is a compile error.
* `os.args[0]` is always the program name as supplied by the OS.
* `os.env` always returns `string?` — use `if let` or `??` to unwrap.
* `os.environ()` returns a heap-allocated `[string]` — the caller owns it and must call `.delete()`.
* `os.exit` bypasses all `defer` blocks. When deferred cleanup is required, return from `main` naturally instead.