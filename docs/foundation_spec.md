# Vertex Language Grammar

## Specification — Foundation (The Lowered View)

---

## 0. What This Is

`foundation.md` is what you write. This is what it becomes: the layout of
every type, what `let`/`var` compile to, and what the runtime does —
which is almost nothing.

One rule governs everything: **every value has a statically known layout,
and every cost is decided at compile time.** No GC, no unwinder, no
vtables, no runtime type info, no drop flags. Anything that would need
one is a compile error instead.

---

## 1. The Machine Model

Vertex lowers to the same substrate C does: stack frames, an explicit
heap, flat functions called through the platform ABI.

Three anchors:

1. **Stack by default.** Every binding is frame-local unless it goes
   through `unique(...)`, `shared(...)`, or a growable container (§7).
2. **Liveness is static.** Conditional transfer is a compile error, so
   the compiler always knows whether a binding is alive. Teardown is
   emitted unconditionally where liveness ends — no drop flags.
3. **Errors are values.** `(T, string)` is an ordinary tuple return.
   No unwind tables exist in a Vertex binary.

---

## 2. Bindings — `let` and `var`

Both are statements about the **binding**, never about heap vs. stack.

| | mutable? | addressable? | lowering |
| --- | --- | --- | --- |
| `let` | no | not guaranteed | register / SSA / folded — a stack slot only if something forces one |
| `var` | yes | guaranteed | a real stack slot for its whole lifetime |

- `let` can never feed a `mut` parameter or receiver — it may not
  physically exist anywhere to point at.
- `var` exists precisely because `mut` parameters are pointers (§9):
  declaring `var` buys the slot the pointer needs.
- `var u = unique(Widget(1))` — the `var` is a mutable one-word stack
  slot; the `unique` decides where the payload lives. Two separate axes.

---

## 3. Scalar Types (thin — one word or less)

A thin value copies by register move. "Deep copy" and "move" are the
same instruction for these.

| Type | Size | What it is |
| --- | --- | --- |
| `int8` | 1 byte | signed integer, −128 … 127 |
| `int16` | 2 bytes | signed integer, −32,768 … 32,767 |
| `int32` | 4 bytes | signed integer, ±2.1 billion |
| `int64` | 8 bytes | signed integer, ±9.2 quintillion |
| `int` | 1 word | signed, platform word width |
| `uint8` / `byte` | 1 byte | unsigned integer, 0 … 255 |
| `uint16` | 2 bytes | unsigned integer, 0 … 65,535 |
| `uint32` | 4 bytes | unsigned integer, 0 … ~4.3 billion |
| `uint64` | 8 bytes | unsigned integer, 0 … ~18.4 quintillion |
| `uint` | 1 word | unsigned, platform word width |
| `float32` | 4 bytes | IEEE 754 single precision |
| `float64` | 8 bytes | IEEE 754 double precision |
| `bool` | 1 byte | `true` / `false` |
| `char` | 4 bytes | one Unicode scalar value in a `uint32` |

Other one-word types:

| Type | Size | What it is |
| --- | --- | --- |
| unit enum | discriminant width | the integer itself, nothing else (§8) |
| `abstract` handle | 1 word | opaque foreign reference (interop §2) |
| `typed_ptr T` | 1 word | raw address, no discipline (memory.md) |
| `unique T` | 1 word | pointer to a sole-owner heap block (§12) |
| `shared T` | 1 word | pointer to a refcounted control block (§12) |
| `weak T` | 1 word | pointer to the same control block (§12) |
| non-capturing `func` | 1 word | bare code pointer (§10) |

One exception to "thin = trivially copied": `unique T` is one word, but
its **bare copy is deep** — it walks and duplicates the pointee. That is
the cost cliff ownership §8.1 warns about. Transfer stays O(1).

---

## 4. Inline Aggregates — the sum of their parts

| Type | Layout |
| --- | --- |
| `struct` | fields in declaration order, ABI padding |
| `class` | **byte-for-byte identical to struct** — init/deinit/receivers/identity are front-end only; no header, no vtable, because there is no inheritance |
| `[N]T` | `N × sizeof(T)` inline, no header; lives wherever its binding or enclosing aggregate lives |
| tuple `(A, B)` | anonymous struct `{A, B}` — bare `return a, b` builds the same bytes as a parenthesized literal |

Copying a struct that embeds a `[1024]uint8` copies the kilobyte,
inline. No pointer exists anywhere in it.

---

## 5. Fat Types — pointer plus metadata

| Type | Shape | Words | Owns pointee? |
| --- | --- | --- | --- |
| `string` | `{ptr, len}` → UTF-8 bytes | 2 | yes |
| slice view `buf[a..b]` | `{ptr, len}` | 2 | **no** — borrowed |
| `[]T` | `{ptr, len, cap}` | 3 | yes (container exception) |
| `map[K]V` | `{ptr}` → table header | 1 | yes |
| capturing closure | `{code, env}` | 2 | yes — owns `env` |
| range `a..b` | `{start, end}` | 2 scalars | n/a — no pointer |

Two rules:

- **Copy depth follows ownership, not width.** A bare copy of an owning
  fat type duplicates header *and* payload — O(data). A transfer copies
  the header and stops — O(1). A slice view owns nothing, so copying it
  is always two words; the compiler pins its lifetime inside the buffer
  it points into.
- **`string` is immutable, and the implementation may exploit it.**
  Because no pathway can mutate string bytes, payloads may be shared or
  interned — observably identical to a deep copy. This license does
  *not* extend to `[]T`, which is mutable and must genuinely duplicate
  on a bare owning copy.

---

## 6. `char` and `string` at the Byte Level

- `char`: one Unicode scalar in a `uint32`. Thin. No allocation.
- `string`: `{ptr, len}` over UTF-8, **no NUL terminator** — the
  terminator is manufactured only at the interop boundary (interop §5).
- `for c in s` decodes UTF-8 into `char` scalars (variable stride);
  `s.bytes()` strides raw `uint8`. Neither allocates.

---

## 7. Fixed Arrays, Dynamic Arrays, Slices

Three bracket types, three layouts:

- **`[N]T`** — inline storage, `N × sizeof(T)`, no pointer. Copies as
  part of whatever contains it.
- **`[]T`** — the container exception: `{ptr, len, cap}` header with an
  implicitly heap-allocated backing block, because "grow at runtime"
  can't fit a fixed frame. The header obeys Rule 0 like any value; the
  block follows the header's ownership. `push` may reallocate (amortized
  doubling), which is why interior pointers into a `[]T` don't exist —
  only lifetime-checked slices do.
- **`buf[a..b]`** — a `{ptr, len}` view. The one foundation type that
  aliases without owning. Treated as a live shared borrow of the buffer:
  the Law of Exclusivity forbids mutating or transferring `buf` while
  the view lives. Never deep-copies, never runs teardown.

**Maps.** `map[K]V` is a one-word handle to a heap table, owned through
the same container exception. `config["debug"] = nil` lowers to an erase
call — this is the load-bearing appearance of `nil`: **`nil` is not a
general value and has no type.** No optional type, no nullable pointer.
Absence is an error tuple (§11), and map-erase is the one place the
grammar admits the literal (plus `typed_ptr`, memory §13).

---

## 8. Enums

- **Unit-only enum** — *is* its discriminant integer. `Status.Active as
  int32` is a reinterpretation, not a conversion. Explicit discriminants
  just pin the values.
- **Payload enum** — a tagged union:

  ```
  enum Shape { Point, Circle(float32), Rectangle(float32, float32) }
    ⇒  { tag: uN, payload: union { (), float32, (float32, float32) } }
  ```

  Sized to the largest variant plus the tag. `switch` reads the tag once
  — dense tags become a jump table, sparse ones a compare chain. Case
  bindings (`case .Rectangle(w, h):`) are views into the payload, not
  copies.
- **Enum copies** are shallow `{tag, payload}` copies — unless a variant
  embeds an owning fat type (`Text(string)`), in which case a deep copy
  recurses into the *live variant only*; the tag tells the copy routine
  which interpretation to walk.

---

## 9. Functions and Calls — the Conventions, Lowered

The three parameter conventions are three physical passing modes. The
most important table in this document:

| Signature | Callee receives | Caller-side lowering |
| --- | --- | --- |
| `x: T` (shared) | read-only view: registers for small values, else a pointer to caller storage | nothing — bare |
| `x: mut T` | the **address** of the caller's `var` slot | nothing — bare; requires an addressable `var` (§2) |
| `x: var T` (owning) | the value itself, by value | `.transfer()` → header memcpy; bare → compiler-inserted deep copy, then moved |

- **Shared** never copies observable state, never permits writes.
  Register vs. pointer is an ABI decision invisible to the program —
  which is why address-less `let` bindings pass fine.
- **`mut`** is literally a pointer parameter: `increment(count)`
  compiles to `increment(&count)`. This is also the whole mechanism
  behind interop's scalar out-param mapping — `mut int32` *is* `int32*`.
  Exclusivity checks make the pointer unique for the call's duration,
  licensing the backend to keep it in a register and spill once.
- **`var`** receives ownership by value (register for thin types, header
  move for aggregates — possibly via hidden sret pointer per ABI). The
  bare-copy branch is the one place caller code grows: the deep copy is
  synthesized at the call site, then handed off exactly like a transfer.
  `.transfer()` itself emits **no code** — it's a liveness marker; the
  "transfer" is the ordinary by-value pass, made legal.
- **Returns.** A tuple return is a physical tuple: small in register
  pairs, large through a caller-provided sret slot. Failure costs the
  same instructions as success.
- **Named arguments** resolve to positional order at compile time — no
  trace in the binary. **Variadics** lower to a stack-local `[N]T` plus
  a `{ptr, len}` view over it.

---

## 10. Function Values and Closures

Two things share a spelling and differ by one word:

- **Non-capturing** — a bare code pointer. One word. The only form that
  crosses the abstract interface boundary (interop §8), because a C
  callback slot is one word wide.
- **Capturing** — `{code, env}`. Each captured binding is **copied by
  value** into `env` at creation (mutating a capture is a compile error
  — you'd be writing a private copy, and the language refuses to let
  that lie compile). The closure owns `env` and tears it down with
  itself; calling passes `env` as a hidden first argument. Writeback is
  explicit: take a `mut` parameter and let the caller thread the
  pointer.

The boundary rejection is arithmetic: `{code, env}` is two words, the
foreign slot holds one, and nothing foreign will own `env`.

---

## 11. Error Tuples, Lowered

The `(T, string)` convention (foundation §35) has no dedicated
machinery. `return Model{}, err` is two stores; `let m, err = ...` is
two loads. The zero value on the error path is a real zeroed `T` — never
partially constructed. Nothing checks `err` for you; that's the
convention's philosophy, explicit over automatic.

This is the same tuple whether the callee is native Vertex or a foreign
boundary function — interop adopts the native shape, not the reverse.

---

## 12. The Heap Doors, Lowered

**`unique(Expr)`** — one allocation, one pointer word.
- Construct: `alloc + move-in`.
- Teardown: `deinit(pointee) + free` at the owner's end of liveness.
- Transfer: move the word. Bare copy: walk the pointee, deep.
- No header beyond the payload — no count, no metadata — which is why
  there is no `unique T → weak T` path: nothing exists for a weak
  reference to check.

**`shared(Expr)`** — allocates a control block:

```
{ strong: atomic uint, weak: atomic uint, payload: T }
```

- The handle is one word pointing at it.
- Copying the handle = atomic increment of `strong`. Always cheap,
  never deep.
- `strong` hits zero → `deinit(payload)`. `weak` also zero → block
  freed. Two-phase teardown is what lets `weak T` safely outlive the
  payload.

**`weak(a)`** — copies the block pointer, bumps `weak`.
**`.upgrade()`** — atomic increment-if-nonzero on `strong`: success
hands back a fresh strong handle and `""`; failure hands back a zero
value and an error string — the `(T, string)` convention applied to a
race the type system can't statically win.

`.transfer()`, `shared()` promotion, and `.upgrade()` are all
compiler-known intrinsics — method-shaped, never dispatched.

**Identity (`===`, classes only)** compares storage addresses: control
block pointers for `shared`, slot addresses for stack bindings. It
answers "same allocation?", never "same bytes?" — that's `==`'s job.

---

## 13. Ranges, Loops, Switch

A range is `{start, end}` — two scalars, no pointer, exclusive by
construction. Every loop lowers to a `while`:

```vertex
for i in 0..5 { body }
      ⇓
var i = 0
while i < 5 { body; i += 1 }
```

- Array iteration: same shape over `{ptr, len}`, stride `sizeof(T)`.
  Shared / `mut` / consuming forms differ only in what the loop variable
  *is* — a view, a pointer, or a moved-out value.
- String iteration strides by decoded scalar; `.bytes()` by byte.
- Map iteration walks the table, order unspecified.
- Slicing and switch-on-range reuse the same two scalars as bounds and
  as a comparison pair. The range type never grows past its two words.

---

## 14. Conversions and Casts

`int8(i)`, `float32(i)`, and `as` all lower to the same conversion
instructions — truncate, extend, int↔float — chosen by width. No
allocation, no call. `enum as intN` is a tag read. There is no dynamic
cast because there is no runtime type info; every `as` is resolved at
compile time, and an impossible one is a compile error.

---

## 15. `defer`, `deinit`, Scope Teardown

Both lower to straight-line calls at scope exit.

- **`defer`** — collected per scope, emitted in reverse registration
  order on every exit edge (fall-through, `return`, `break`,
  `continue`). No unwinder means "every exit edge" is a finite, static
  set. A `defer` costs exactly the call it defers.
- **`deinit`** — emitted where a binding's liveness ends: fields in
  reverse declaration order, locals in reverse declaration order.
- **A transferred binding simply has its teardown not emitted.** No flag
  set, no flag checked — `.transfer()` moved the end of liveness to the
  transfer site, and the destination inherited the obligation. The
  compile errors on conditional transfer exist to keep this true: the
  moment "was it transferred?" becomes a runtime question, Vertex would
  need drop flags, so the language forbids the question.

---

## 16. What a Vertex Binary Does *Not* Contain

The negative space is the point:

| Absent | Replaced by |
| --- | --- |
| Garbage collector | static liveness + scope teardown (§15); refcounts only where you wrote `shared` |
| Exception unwinder | the `(T, string)` tuple, ordinary control flow (§11) |
| Vtables / dynamic dispatch | no inheritance; all calls direct (§4) |
| Drop flags | conditional transfer is a compile error (§1, §15) |
| Null-pointer discipline | no general `nil`; absence is an error tuple (§7, §11) |
| Runtime type info | all casts static (§14) |
| Hidden allocation | heap only via `unique` / `shared` / containers, all spelled in source (§12) |

Every row is the same trade in the same direction: a runtime question
converted into a compile-time proof or a visible piece of syntax.
`foundation.md` is the syntax; this document is the proof obligations it
discharges.