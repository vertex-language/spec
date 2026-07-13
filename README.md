# Vertex Language Specification

**Version 2.2**

This repository contains the formal grammar specification for Vertex, a
statically-typed systems language with explicit ownership sigils, a
C-flavored machine model (no GC, no vtables, no runtime type info),
first-class concurrency primitives, native hardware-acceleration
extensions (GPU/TPU), and a structural foreign-interop layer.

This README is the top-level entry point. Detailed grammar lives under
[`docs/`](docs/).

---

## Document Map

| Doc | Covers |
|---|---|
| [`docs/foundation.md`](docs/foundation.md) | Literals, types, operators, control flow, functions, closures, arrays, maps, structs, enums, classes, tuples, imports, error handling (`(T, string)` tuples), compiler testing |
| [`docs/foundation_spec.md`](docs/foundation_spec.md) | The lowered view of the above — memory layout of every type, what `let`/`var` compile to, the calling conventions, and what the runtime does (almost nothing) |
| [`docs/ownership.md`](docs/ownership.md) | The shared / `mut` / `var`+`.transfer()` model — grammar reference |
| [`docs/ownership_spec.md`](docs/ownership_spec.md) | Same model, plus the root concepts (aliasing, mutation, liveness), the Law of Exclusivity, and the cost-model rationale behind each sigil |
| [`docs/generics.md`](docs/generics.md) | Type parameter lists, constraints (type-set and method), the standard constraint library, instantiation/inference, monomorphization |
| [`docs/concurrency.md`](docs/concurrency.md) | `thread` / `async` call-site sigils, auto-channeling single-return calls, explicit `chan T`, `select` |
| [`docs/accel.md`](docs/accel.md) | `gpu` / `tpu` sigils, the `tensor[ElementType, Shape...]` type, and the `tpu.` builtin namespace |
| [`docs/abstract_interfaces.md`](docs/abstract_interfaces.md) | Foreign interop grammar — `abstract` handles, the boundary tuple, structural ABI typing (flat vs. object APIs), safe wrapper classes |
| [`docs/abstract_interfaces_spec.md`](docs/abstract_interfaces_spec.md) | Same material, plus the two-layer interop philosophy and the reasoning behind each mapping |
| [`docs/memory.md`](docs/memory.md) | `typed_ptr T` — the raw, last-resort pointer: arithmetic, indexing, casting, `new`/`delete`/`resize`, `copy`/`zero`, `nil` |

Files without a `_spec` companion (`generics.md`, `concurrency.md`,
`accel.md`) are self-contained — grammar and rationale inline.
`foundation.md`/`ownership.md`/`abstract_interfaces.md` are the terse
grammar-only reference; their `_spec` counterparts carry the same
examples plus the "why" and the machine-level consequences.

---

## Language at a Glance

### Bindings & Types

```vertex
let x = 10            // immutable
var y = 20             // mutable
let a: int32 = 100      // explicit annotation
type size_t = uint64    // alias
let b: byte = 0xFF      // byte is the preferred spelling for uint8
```

Numeric types: `int8/16/32/64`, `uint8/16/32/64` (`byte` = `uint8`),
`float32/64`, plus platform-width `int`/`uint`. Casts via constructor
call (`int32(x)`) or `as` (`x as int64`).

### Ownership — shared / exclusive / owning

Every parameter's convention is visible in the signature; only the
owning convention also shows up at the call site.

```vertex
func f1(x: T)           f1(x)                  // shared  — bare, always
func f2(x: mut T)        f2(x)                  // exclusive — bare, checked via signature
func f3(x: var T)        f3(x)  / f3(x.transfer())   // owning — COPY (bare) or TRANSFER (marked)
```

There's no `.clone()` — a bare hand-off to an owning parameter is a
deep copy; `.transfer()` is the only marked operation, and it's O(1)
(header only) versus a copy's O(data). `unique T` and `shared T` are
the two heap doors; `weak T` observes a `shared T` without keeping it
alive. See [`ownership.md`](docs/ownership.md) and
[`ownership_spec.md`](docs/ownership_spec.md).

### Control Flow, Data Types, Errors

Standard `if`/`else if`/`else`, `switch` (with `fallthrough`, range
cases), `while`, one `for-in` form over ranges/arrays/maps/strings,
fixed (`[N]T`) and dynamic (`[]T`) arrays, `map[K]V`, `struct`/`enum`
(unit, tuple, and mixed variants, explicit discriminants), `class` with
`init`/`deinit`, and tuples (positional or named; parens construct,
bare commas destructure). There is no optional type and no exception
unwinder — every fallible or possibly-absent value is a
`(T, string)` boundary tuple, checked with a plain `if err != ""`. All
detailed in [`foundation.md`](docs/foundation.md).

### Generics

Unconstrained by default (`[T]` means `[T: any]`); constraints are
declared as their own type-set or method contracts, not interfaces.
Vertex monomorphizes — every instantiation is a separate compiled
body, so a generic that's never instantiated emits no code and an
unsatisfied constraint is a compile error at the instantiation site.

```vertex
func min[T: constraints.Ordered](a: T, b: T) -> T {
    if a < b { return a }
    return b
}
struct Pair[A, B] { first: A  second: B }
enum Option[T] { None, Some(T) }
```

See [`generics.md`](docs/generics.md).

### Concurrency

```vertex
let a = async fetch_network(id: 1)
let b = thread heavy_compute(data: x)
```

`thread`/`async` are call-site sigils, not function qualifiers — the
same function can be dispatched either way, or called synchronously
with neither. A call returning `T` auto-channels into a
`.receive()`-able handle; streaming work uses an explicit `chan[T]`
with blocking/non-blocking send/receive and a Go-style `select`. See
[`concurrency.md`](docs/concurrency.md).

### Hardware Acceleration

```vertex
let d   = gpu(blocks: 16, threads: 256) matrix_mult(x, y)
let sum = tpu vecAdd(ha, hb)   // tensor[float32, 1024] channeled to/from host arrays
```

`gpu` compiles ordinary Vertex to PTX/SPIR-V with no restricted
types. `tpu` channels host arrays into `tensor[ElementType, Shape...]`-
typed function bodies, with a dedicated `tpu.` builtin namespace (math,
contraction, selection, shape, reduction, constants) and restricted
control flow (scalar-only conditions, no `break`/`continue` in
`while`). See [`accel.md`](docs/accel.md).

### Foreign Interop — Abstract Interfaces

No raw pointers exposed by default — a foreign resource is an opaque
`abstract` handle, and a fallible foreign call maps to the same
`(T, string)` boundary tuple used everywhere else in the language.

```vertex
type SDL_Window = abstract

class SDL2_API : sdl2 {
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32)
        -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
}
```

Whether an interface is a flat C-style namespace or an instantiable
object (Objective-C, C++, JS) is inferred structurally from whether it
declares any `init func` — no `objc`/`cpp`/`js` keyword needed. Ordinary
Vertex wrapper classes hold the handle and manage its lifetime in
`init`/`deinit`; the interface itself is declaration-only. For the
residue an `abstract` handle and the safe pointer shapes (`mut T`,
`[]T`) can't express, there's `typed_ptr T` — see
[`memory.md`](docs/memory.md). See
[`abstract_interfaces.md`](docs/abstract_interfaces.md) for the grammar
and [`abstract_interfaces_spec.md`](docs/abstract_interfaces_spec.md)
for the two-layer (interface vs. wrapper) reasoning.

---

## Reading Order

New to the grammar? Suggested path:

1. `foundation.md` — core syntax and types
2. `ownership_spec.md` — the sigil system everything else builds on
3. `generics.md` — how type parameters interact with ownership
4. `concurrency.md` — `thread`/`async` sigils and channels
5. `accel.md` — GPU/TPU extensions (builds on ownership + generics)
6. `abstract_interfaces_spec.md` — foreign interop (builds on ownership's `mut`/`var`)
7. `memory.md` — `typed_ptr T`, the raw-pointer escape hatch interop falls back to
8. `foundation_spec.md` — the machine model everything above lowers to

## Versioning

All documents in this repository are pinned to **Specification 2.2**.
Section numbers are stable within a spec version and are
cross-referenced across documents (e.g. `ownership.md §3`,
`foundation.md §35.2`, `memory.md §8`).