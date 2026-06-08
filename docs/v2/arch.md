# Vertex Compiler Architecture

## Pipeline

```
sample.vs
    ↓
Parser
    ↓
AST
    ↓
Resolver / Type Checker
    ↓
Typed AST
    ↓
Lowerer             ← syntax sugar erased, builtin/* calls emitted
    ↓
ir/c builder        ← C semantics, ABI, struct layout, calling conventions
    ↓
MIR                 ← flat instruction list, register allocation
    ↓
Encoder             ← amd64 / arm64 / freestanding
```

Each level has one job and hands a fully-formed artifact to the next.
No level reaches backwards.

---

## Level 1 — Parser

Reads Vertex source and produces a raw AST. No type information exists yet.
Nodes are structural only.

```
sample.vs  →  Parser  →  AST
```

Relevant raw node types:

```
DictLiteral       ["debug": 0]
ArrayLiteral      [1, 2, 3]
StringLiteral     "hello"
FuncCall          foo(x: 1)
DeferStmt         defer x.delete()
MutParam          func f(n: mut int32)
NewExpr           Animal(...).new()
```

The parser has no knowledge of `builtin/*`, types, or machine targets.

---

## Level 2 — Resolver / Type Checker

Walks the raw AST and produces a Typed AST. Every node is decorated with
a resolved type. Name resolution, type inference, and type checking all
happen here.

```
AST  →  Resolver / Type Checker  →  Typed AST
```

After this pass:

- `["debug": 0]` is known to be `map[string, int32]`
- `[int32](capacity: 64)` is known to be a dynamic `Array<int32>`
- `[uint8](1024)` is known to be a static fixed array
- `"hello"` bound to `let` is known to be an immutable `.rodata` string
- `"hello"` bound to `var` is known to be a mutable `strings.String`
- Every `defer` target has a resolved type and call signature

The resolver has no knowledge of `ir/c` or machine targets.

---

## Level 3 — Lowerer

The Lowerer is the critical translation layer. It walks the Typed AST and
emits `ir/c` builder calls. This is where all Vertex syntax sugar is erased
and high-level concepts are replaced with explicit `builtin/*` operations.

```
Typed AST  →  Lowerer  →  ir/c builder calls
```

The Lowerer has hardcoded knowledge of `builtin/*` package names. This is
not a design flaw — `builtin/*` is guaranteed to be present at compile time
for every Vertex program.

### Syntax sugar mappings

| Typed AST node | Lowerer emits |
|---|---|
| `DictLiteral` | `maps.new` + `maps.insert` per entry |
| `ArrayLiteral` (dynamic) | `arrays.new` + `arrays.push` per element |
| `ArrayLiteral` (static) | `b.MemZero` — stack allocation, no builtin |
| `StringLiteral` on `let` | `c.StringLit` — `.rodata`, no builtin |
| `StringLiteral` on `var` | `strings.new` |
| `DeferStmt` | hoisted cleanup call inserted before every return path |
| `MutParam` | rewritten to pointer parameter + auto-deref at all usage sites |
| `.new()` | `ref_count` field injected into struct layout + retain/release emitted |

From this point `ir/c` sees only `b.Call()` nodes. It has no knowledge of
what a hash map is.

---

## Level 4 — ir/c Builder

The `ir/c` builder is a structured Go-native builder for a strict subset of C
semantics. It receives `ir/c` builder calls from the Lowerer and is responsible
for ABI correctness, struct layout, bitfield packing, calling conventions,
and volatile/atomic semantics.

```
ir/c builder calls  →  ir/c  →  Optimize()  →  EmitC() / MIR
```

### ir/c pipeline

```
ir/c builder
    ├── Optimize()   →  ConstantFold · DeadCodeElim · StrengthReduce
    ├── EmitC()      →  readable C source (debug / inspection)
    └── Lower()
            ↓
           MIR        ←  flat instruction list · register allocation
            ↓
         Encoder      ←  amd64 · arm64 · freestanding
```

---

## Package Layers

Two layers sit beneath user code and are never imported directly.
Each is documented separately.

```
intrinsics/*      every call inlined → no symbol, no CALL    see intrinsics.md
      ↓  used by
builtin/*         real symbols, real CALL instructions        see builtins.md
      ↓  hardcoded by
Lowerer           emits b.Call("maps_new", ...) etc.
      ↓
user code         never imports either layer directly
```

---

## Package Compilation Order

Every Vertex compilation resolves packages in this order.
No stage may depend on a stage below it.

```
1.  intrinsics/*     build intrinsics — compiled first, always
                     no runtime presence, inlined at every call site
        ↓
2.  builtin/*        mem · maps · arrays · strings
                     real symbols — depend only on intrinsics/*
                     hardcoded target of the Lowerer
        ↓
3.  core/            mem · sync · io · sys
                     depends on intrinsics/sys · intrinsics/memory
        ↓
4.  user packages    normal Vertex packages
        ↓
5.  user main        entry point
```

---

## End-to-End Example

Vertex source (`sample.vs`):

```swift
func main() -> int32 {
    var config = ["debug": 0]
    config["verbose"] = 1
    defer config.delete()
    return 0
}
```

**Level 1 — Parser:**

```
FuncDecl main -> int32
  VarDecl config
    DictLiteral
      Entry("debug",   IntLit 0)
  IndexAssign config["verbose"] = IntLit 1
  DeferStmt  config.delete()
  Return     IntLit 0
```

**Level 2 — Resolver:**

```
FuncDecl main -> int32
  VarDecl config: map[string, int32]
    DictLiteral<string, int32>
      Entry("debug",   IntLit(0): int32)
  IndexAssign config["verbose"]: int32 = IntLit(1)
  DeferStmt  config.delete() : maps.Map.free
  Return     IntLit(0): int32
```

**Level 3 — Lowerer:**

```go
fn := m.Func("main", c.Returns(c.Int32))
fn.Body(func(b *c.Builder) {
    config := b.Local("config", mapsMapPtr)
    b.Assign(config, b.Call("maps_new",
        c.FuncRef("maps_str_hash"),
        c.FuncRef("maps_str_equal"),
    ))
    b.Stmt(b.Call("maps_insert", config,
        c.StringLit("debug"),   c.IntLit(0)))
    b.Stmt(b.Call("maps_insert", config,
        c.StringLit("verbose"), c.IntLit(1)))

    // defer hoisted before return
    b.Stmt(b.Call("maps_free", config))
    b.ReturnVal(c.IntLit(0))
})
```

**Level 4 — ir/c EmitC() output:**

```c
/* Generated by ir/c — do not edit */
#include <stdint.h>
#include <stdbool.h>
#include "builtin/maps.h"

int32_t main(void)
{
    maps_Map *config = maps_new(maps_str_hash, maps_str_equal);
    maps_insert(config, "debug",   0);
    maps_insert(config, "verbose", 1);
    maps_free(config);
    return 0;
}
```

No GLib. No external dependency. `maps_new`, `maps_insert`, and `maps_free`
are symbols compiled from `builtin/maps.vx` using `intrinsics/memory` and
`intrinsics/bit`.