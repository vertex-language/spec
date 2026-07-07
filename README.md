# Vertex Language Specification

**Version 2.2**

This repository contains the formal grammar specification for Vertex, a
statically-typed systems language with explicit ownership sigils, a
Rust/C++-flavored memory model, first-class concurrency primitives, and
native hardware-acceleration extensions (GPU/TPU).

This README is the top-level entry point. Detailed grammar lives under
[`docs/`](docs/).

---

## Document Map

| Doc | Covers |
|---|---|
| [`docs/foundation.md`](docs/foundation.md) | Literals, types, operators, control flow, functions, arrays, maps, optionals, structs, enums, classes, tuples, imports, first-class functions, error handling, compiler testing |
| [`docs/ownership.md`](docs/ownership.md) | The borrow / `mut` / consume (`&`) model — pure grammar forms |
| [`docs/ownership_semantics.md`](docs/ownership_semantics.md) | Same material as `ownership.md`, plus the C++/Rust lineage and rationale behind each sigil |
| [`docs/concurrency.md`](docs/concurrency.md) | `thread` / `async` execution sigils, channels, `select` |
| [`docs/generics.md`](docs/generics.md) | Generic functions, structs, enums, methods; unconstrained type parameters |
| [`docs/ffi.md`](docs/ffi.md) | C interop grammar — opaque handles, pointer-shape mapping, flat ABI bindings |
| [`docs/ffi_semantics.md`](docs/ffi_semantics.md) | Same material as `ffi.md`, plus the reasoning behind each interop form |
| [`docs/accel.md`](docs/accel.md) | `gpu` / `tpu` sigils, the `tensor<ElementType; Shape>` type, and the `tpu.` builtin namespace |

Files without a `_semantics` companion (`foundation.md`, `concurrency.md`,
`generics.md`, `accel.md`) are self-contained — grammar and rationale
inline. `ownership.md` / `ffi.md` are the terse grammar-only reference;
their `_semantics` counterparts carry identical code samples plus the
"why," including comparisons to C++ and Rust.

---

## Language at a Glance

### Bindings & Types

```vertex
let x = 10          // immutable
var y = 20           // mutable
let a: int32 = 100    // explicit annotation
type size_t = uint64  // alias
```

Numeric types: `int8/16/32/64`, `uint8/16/32/64`, `float32/64`, plus
`int`/`uint` general aliases. Casts via constructor call (`int32(x)`) or
`as` (`x as int64`).

### Ownership — the borrow / `mut` / consume ladder

Vertex's signature feature: every parameter's ownership *convention* is
visible both in the function signature and, for anything beyond a plain
read, at the call site too.

```vertex
func f1(x: T)     f1(x)          // read      — silent, default
func f2(x: mut T)  f2(mut x)      // mutate    — marked both ends
func f3(x: T&)     f3(x&)         // consume   — marked both ends, move-only
```

See [`ownership.md`](docs/ownership.md) for the full ladder
(receivers, `shared<T>`, conditional/loop move errors, exclusivity
rules) and [`ownership_semantics.md`](docs/ownership_semantics.md)
for why it's shaped this way relative to C++'s silent `T&` and Rust's
silent moves.

### Control Flow, Data Types, Errors

Standard `if/else`, `switch` (with `fallthrough`), `while`, `for-in`,
fixed/dynamic arrays, `map<K, V>`, `T?` optionals with `if let` /  `??`,
`struct`/`enum` (unit, tuple, and mixed variants, explicit
discriminants), `class` with `init`/`deinit`, and tuples (positional or
named, with destructuring). Error handling favors return-based
conventions (`(T, string)`, `T?`, `?` propagation, `if let ... else ->`)
over exceptions. All detailed in
[`foundation.md`](docs/foundation.md).

### Generics

Unconstrained type parameters only — no `where` clauses, no trait
bounds. Errors surface at instantiation, not declaration.

```vertex
func largest<T>(list: [T]) -> T { ... }
struct Stack<T> { items: [T] = [] }
enum Result<T, E> { Ok(T), Err(E) }
```

See [`generics.md`](docs/generics.md).

### Concurrency

```vertex
let a = async fetch_network(id: 1)
let b = thread heavy_compute(data: x)
```

`thread`/`async` are call-site sigils, not function qualifiers — the
same function can be dispatched either way. Single-return calls
auto-channel into a `.receive()`-able handle; streaming calls use
explicit `chan T` channels with blocking/non-blocking send/receive and
a Go-style `select`. See [`concurrency.md`](docs/concurrency.md).

### Hardware Acceleration

```vertex
let d = gpu(blocks: 16, threads: 256) matrix_mult(x, y)
let sum = tpu vecAdd(ha, hb)   // tensor<float32; 1024> channeled to/from host array
```

`gpu` compiles ordinary Vertex to PTX/SPIR-V. `tpu` channels host
arrays into `tensor<ElementType; Shape>`-typed function bodies, with a
dedicated `tpu.` builtin namespace (math, contraction, selection,
shape, reduction, constants) and restricted control flow (scalar-only
conditions, no `break`/`continue` in `while`). See
[`accel.md`](docs/accel.md).

### FFI & Native Interop

C interop with no raw pointers exposed to the programmer:

| C shape | Vertex form |
|---|---|
| Opaque resource handle | `type X = unique` (linear, move-only) |
| `const char*` | `cstr` |
| `T*` scalar out-param | `mut T` |
| `T**` (new owned object) | plain return `-> T?` |
| `T*` + length | `[T]` / `mut [T]` |

Bindings are declared with the FFI-only `class X : lib_name { ... }`
form (a stateless linker symbol table, *not* inheritance). See
[`ffi.md`](docs/ffi.md) for the grammar and
[`ffi_semantics.md`](docs/ffi_semantics.md) for the
per-function decision rule (bare / `mut` / `&`) and callback trampoline
handling.

---

## Reading Order

New to the grammar? Suggested path:

1. `foundation.md` — core syntax and types
2. `ownership_semantics.md` — the sigil system everything else builds on
3. `generics.md` — how type parameters interact with ownership
4. `concurrency.md` — thread/async sigils and channels
5. `accel.md` — GPU/TPU extensions (builds on ownership + generics)
6. `ffi_semantics.md` — native interop (builds on ownership's `unique`/`mut`/`&`)

## Versioning

All documents in this repository are pinned to **Specification 2.2**.
Section numbers are stable within a spec version and are cross-referenced
across documents (e.g. `ownership.md §3`, `foundation.md §31.6`).