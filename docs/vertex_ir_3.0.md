# Vertex IR 3.0

## Overview

Vertex IR 3.0 unifies the compiler pipeline around a single insight: **C headers
are just ir/c node declarations waiting to be parsed**. Rather than manually
writing Native Interface class declarations to describe C library signatures,
the compiler parses C headers directly, translates them into ir/c nodes, and
merges them into the same node tree as Vertex-compiled source. By the time the
tree reaches ir/mir, all nodes are identical regardless of origin.

The second insight follows from the first: because ir/c can emit valid,
readable C source via `EmitC()`, the compiler gains a free safety path —
compile to C, validate with gcc, and if that's clean, compile the same tree
natively through ir/mir without touching gcc again.

---

## The Pipeline

```
Vertex Source (.vs)
        │
        ▼
  Vertex Frontend
  (parse · typecheck · semantic analysis)
        │
        ▼
  ir/c nodes  ◄────────────────────────────────┐
        │                                       │
        │                              C Header Parser
        │                        (triggered by import "std/*")
        │                                       │
        │                              translates .h declarations
        │                              to ir/c extern / struct /
        │                              alias / constant nodes
        │                                       │
        └───────────────────────────────────────┘
                          │
                          ▼
               merged ir/c node tree
                          │
              ┌───────────┴────────────┐
              │                        │
         Optimize()                    │
    ConstantFold                       │
    DeadCodeElim                       │
    StrengthReduce                     │
              │                        │
              ▼                        ▼
          EmitC()                   ir/mir
      readable C source        register allocation
              │                        │
              ▼                        ▼
            gcc                  encoder/amd64
      (debug · test ·                  │
       safety validation)              ▼
                                  object file (.o)
                                       │
                                       ▼
                                    linker
                                  executable
```

---

## The Header Parser

C headers are declarations. Every declaration in a header maps directly to
an ir/c node type that already exists.

| C header construct                        | ir/c node produced              |
|-------------------------------------------|---------------------------------|
| `extern int printf(const char *, ...)`    | extern node · variadic flag     |
| `typedef unsigned long size_t`            | alias node                      |
| `struct stat { ... }`                     | struct node · layout fields     |
| `union { ... }`                           | union node                      |
| `#define SEEK_SET 0`                      | constant node (integer)         |
| `#define NULL ((void*)0)`                 | constant node (void ptr)        |
| `enum { AF_INET = 2, ... }`              | constant nodes (per member)     |

The parser runs **target-aware** — the module's bound target is passed in so
that preprocessor conditionals (`#ifdef __linux__`, `#if __WORDSIZE == 64`)
evaluate correctly. The output nodes carry the same ABI layout information
as hand-authored ir/c nodes.

Function-like macros (`#define MAX(a, b) ...`) do not map cleanly to nodes
and are skipped in the initial pass. Object-like macros and all declaration
forms are fully supported.

---

## Import Path Model

The import path now routes to one of two resolution strategies:

```
import "std/stdio"       →  parse system header <stdio.h>  →  ir/c nodes
import "std/stdint"      →  parse system header <stdint.h> →  ir/c nodes
import "lib/mylib"       →  Native Interface class decl    →  ir/c nodes
import "linux/syscalls"  →  Native Interface class decl    →  inline syscall
import "gpu/cuda"        →  Native Interface class decl    →  PTX emission
import "metal/int10h"    →  Native Interface class decl    →  interrupt emission
```

For `std/*` and any `lib/*` path that has a corresponding header on the
system, the compiler can resolve the nodes automatically without a class
declaration. The Native Interface class pattern remains the correct path
for reshaping or renaming a C API at the Vertex boundary, or for any
non-C emission target.

Usage at the call site is unchanged — the developer just uses the functions
directly once the import is in scope:

```swift
import "std/stdio"
import "std/stdint"

func main() -> int {
    printf("hello %d\n".any(), 42)
    return 0
}
```

No `class C : c { ... }` wrapper needed. No instance. The extern node for
`printf` was injected from the parsed header and is available directly in
the module scope.

---

## The Dual Compilation Path

The architecture provides two distinct routes from a single ir/c node tree.
Both paths start from the **same merged tree after optimization**.

### Path A — gcc (debug · test · validation)

```
ir/c tree  →  EmitC()  →  fib.c  →  gcc -O2  →  executable
```

- Produces human-readable, inspectable C source.
- gcc acts as an independent validator — if gcc accepts and the output is
  correct, the ir/c tree is sound.
- Full gcc diagnostics, sanitizers (`-fsanitize=address,undefined`), and
  debug info (`-g`) are available at no extra cost.
- The emitted C includes all necessary system headers at the top, so it
  compiles standalone without any changes.

```bash
vertex -emit-c -o fib.c fib.vs      # emit C source
gcc -O2 -fsanitize=undefined fib.c  # validate with gcc
```

### Path B — native (production)

```
ir/c tree  →  ir/mir  →  encoder/amd64  →  .o  →  linker  →  executable
```

- ir/mir takes the merged, optimized node tree directly — no C involved.
- Register allocation, instruction selection, and ABI enforcement happen
  inside the Vertex compiler.
- Calling conventions and struct layouts were already enforced at the ir/c
  layer, so ir/mir sees a clean, ABI-correct representation.
- No gcc dependency at runtime or on the target machine.

```bash
vertex -o fib fib.vs                # compile natively
```

Both paths consume the **same ir/c tree**. A program that passes gcc
validation is ready for native compilation with no further changes.

---

## Node Merge

The merge happens after both the Vertex frontend and the header parser have
produced their ir/c nodes, and before any optimization pass runs.

```
vertex frontend nodes     ┐
                           ├──► module node tree  ──►  Optimize()  ──►  emit/lower
C header parser nodes     ┘
```

The module node tree holds:

- Function definitions (from Vertex source)
- Extern function declarations (from header parser or Native Interface)
- Struct / union definitions (from header parser or `c.Struct(...)`)
- Type aliases (from header parser `typedef` or `m.Alias(...)`)
- Constants (from header parser `#define` or `c.IntLit(...)`)
- String literals and globals

From ir/mir's perspective all nodes are equivalent. A call to `printf`
from a parsed header node and a call to a Vertex-defined function are
the same kind of call node in MIR.

---

## What Stays from Native Interface

The Native Interface class declaration pattern is **not retired**. It remains
the correct tool for:

| Case | Reason |
|------|--------|
| Reshaping or renaming a C API | Class gives you the mapping surface |
| `linux/` syscall targets | No header — compiler emits inline syscall |
| `gpu/` CUDA / shader kernels | No header — compiler emits PTX |
| `darwin/` Objective-C dispatch | Selector emission, not a linked call |
| `windows/` COM / vtable dispatch | Slot order, not a linked call |
| `metal/` bare metal interrupts | No linker, no header |
| Libraries with no system headers | Declare the sig manually |

The rule of thumb: if a header exists and the sig can be consumed as-is,
let the parser handle it. If the emission strategy is anything other than
a standard linked call, use Native Interface.

---

## Benefits

**Ecosystem compatibility.** Any C library with headers is immediately
usable from Vertex without writing wrapper classes. The entire POSIX surface,
all platform SDKs, every third-party C library — resolved by the parser.

**gcc as a free validator.** The C emission path gives correctness checking
by a mature, hardened compiler at no implementation cost. Shipping a new
ir/c feature? Emit C first, run gcc with sanitizers, then enable the native
path with confidence.

**Single source of truth.** There is one node tree. The C source that gcc
compiles and the machine code that the native path emits come from the
same optimized ir/c representation. They cannot diverge.

**No gcc dependency in production.** The native path — ir/mir → encoder →
object file → linker — is entirely self-contained. gcc is a development
and validation tool, not a runtime requirement.

**Gradual migration.** Any part of the pipeline can be verified independently:
- Vertex frontend correct? Check the ir/c nodes.
- ir/c optimization correct? Emit C, diff before/after.
- MIR lowering correct? Compare native output against gcc output.
- Encoder correct? Compare object file against gcc-produced object.

Each layer has a concrete, inspectable artifact at every stage.

**ABI correctness by construction.** Struct layouts, bitfield packing,
calling conventions, and volatile/atomic semantics are all enforced at
the ir/c layer before MIR sees the tree. The native path inherits this
correctness — it does not need to re-derive ABI rules from scratch.

---

## Summary

| What changed | Detail |
|---|---|
| `std/*` imports | resolved by C header parser, not Native Interface class |
| Header parser output | ir/c nodes, merged before optimization |
| Native Interface | retained for non-C emission targets and API reshaping |
| gcc path | `EmitC()` → gcc — validation, debugging, sanitizers |
| Native path | ir/mir → encoder/amd64 → .o → linker — no gcc dependency |
| MIR node origin | irrelevant — all nodes equivalent by merge time |
| Single tree | one optimized ir/c tree drives both paths |