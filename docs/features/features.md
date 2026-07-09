# Vertex — Features

## Memory Safety Without Pointer Syntax

- **Zero sigils.** No `&`, no `*`, no lifetime annotations. Indirection is an implementation detail, never part of a type the user writes.

- **Four conventions, one slot.** The colon carries the whole contract:
  ```vertex
  x: T          // shared access — read-only, the silent default
  x: mut T      // exclusive access — scoped to one call
  x: own T      // ownership transfer — the callee keeps it
  unowned f: T  // stored back-pointer — field-only, compile-proved
  ```

- **Rule 0 — access is second-class.** A `mut` grant lives for exactly one call: not storable, not returnable, not capturable. Escaping references are unrepresentable, so lifetimes never need names.

- **Law of Exclusivity.** Aliasing or mutation, never both — checked at every call site, receiver chains and anchors included.

- **Move Invalidation.** Use-after-move is a compile error, including through branches and loops. Moves are silent at the call site because the checker polices every later use.

- **Mark what the compiler can't catch.** `mut` is required at the call site — mutation is the one effect nothing downstream would reveal. Reads, moves, and anchored access stay silent because their misuse is already impossible or already caught.

## Cost Model (stated, not implied)

| operation | spelling | cost |
|---|---|---|
| shared access | bare | free |
| exclusive access | `mut x` | free |
| move | `x` (to `own` param) | O(1) header copy |
| deep copy | `x.clone()` | O(data) — the only explicit one |
| anchored hop | `b.parent` | one pointer load, zero checks |
| weak upgrade | `w.upgrade()` | runtime branch + count traffic |

## Two Back-Edges

- **`unowned`** — for unique ownership trees. Proven once, at one anchoring statement (`a.b = ClassB(parent: a)`); free forever after. Pinned: can't be moved out, promoted, or captured.
- **`weak<T>`** — for `shared<T>` graphs where cycles are possible. Runtime-checked via `upgrade()`, the price of a lifetime the compiler can't see.

## Elsewhere

- Value semantics by default; `shared<T>` opts into refcounted multi-ownership.
- Errors as values: tuples, optionals, `?` propagation, `if let / else ->`.
- Structs, enums with associated data, receiver-syntax methods, `defer`, first-class function types with value-capture closures.
- Built-in compile-and-run testing: `test` qualifier, `Expected(...)`, including compile-failure tests.
- Mutable globals banned — reentrancy can't smuggle aliased access past call-site checks.