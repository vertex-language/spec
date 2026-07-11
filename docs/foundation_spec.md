# Vertex Language Grammar

## Specification — Foundation (The Lowered View)

---

## 0. What This Document Is

`foundation.md` shows what you write. This document specifies what it becomes: the physical layout of every value, what `let` and `var` compile to, which types are one word and which are fat, and what the runtime does — which is, deliberately, almost nothing.

The governing principle: **every Vertex value has a layout the compiler knows statically, and every cost is decided at compile time.** There is no garbage collector, no exception unwinder, no vtable, no runtime type information, and no drop flags. If a feature would require any of those, the language doesn't have that feature — it has a compile error instead. This document walks through the foundation grammar and shows how each construct survives (or dissolves) under that rule.

---

## 1. The Machine Model

Vertex lowers to the same substrate C does: a stack of frames, a heap you ask for explicitly, and flat functions called through the platform ABI. The compiler's whole job is to translate the ownership and access rules into that substrate *and then disappear*. Nothing in this spec describes a runtime service; everything describes a layout or an instruction sequence.

Three facts anchor everything below:

1. **The stack is the default.** Every binding is frame-local storage unless it goes through one of the two heap doors (`unique(...)`, `shared(...)`) or the container exception (§6).
2. **Liveness is static.** Because conditional transfer is a compile error (ownership §6.7), the compiler always knows *at compile time* whether a binding is alive at any program point. This is why Vertex needs no runtime drop flags: teardown code is emitted unconditionally, exactly where liveness ends.
3. **Errors are values.** The `(T, string)` convention (foundation §35) means the failure path is an ordinary tuple return. There are no unwind tables anywhere in a Vertex binary.

---

## 2. Bindings — What `let` and `var` Actually Mean

`let` and `var` are statements about the **binding**, not about the value's storage class. Neither one ever means "heap."

### 2.1 `let` — immutable, address-optional

```vertex
let x = 10
let w = Widget(1)
```

A `let` binding can never be the subject of exclusive access: it cannot be assigned to, cannot be passed to a `mut` parameter, and cannot be a `mut` receiver. Because nothing may ever write through it, the compiler is free to keep it in a register, fold it into SSA form, or duplicate it across uses — a `let` is not guaranteed to have an address at all. It only materializes into a stack slot if something structurally needs one (its address escapes into a shared-access call for a large aggregate, say).

`let` restricts the *binding*, not the pathway. `let w = Widget(1)` followed by `inspect(w)` is a shared borrow like any other; the immutability of `w` is what makes the no-address optimization sound.

### 2.2 `var` — mutable, addressable

```vertex
var count = 0
increment(count)      // increment takes n: mut int32
```

A `var` binding is guaranteed a real, addressable stack slot for as long as it's live. The reason is mechanical: a `mut` parameter lowers to a pointer (§8.2), and a pointer needs something to point at. Declaring `var` is how you buy that slot. This is also why only `var` bindings can be passed to `mut` parameters — a `let` may not physically exist anywhere.

### 2.3 The Two Axes, Kept Apart

|  | binding mutability | storage location |
| --- | --- | --- |
| `let` / `var` | decided here | says nothing |
| `unique(...)` / `shared(...)` | says nothing | decided here |

`var u = unique(Widget(1))` is a mutable *stack* slot one word wide, holding a pointer to a *heap* allocation. The `var` governs the word on the stack; the `unique` governs the bytes behind it. The spelling collision with the `var` parameter keyword (ownership §3) is resolved by position: `var` at a declaration is binding mutability, `var` in a signature is the owning convention.

---

## 3. The Layout Catalogue — Thin, Inline, Fat

Every type in the foundation lowers to one of three physical shapes.

### 3.1 Thin — one word or less

```
int8..int64, uint8..uint64      exact-width integers
float32, float64                IEEE 754
bool                            one byte
char                            uint32 — a Unicode scalar value
unit enums                      their discriminant integer, nothing else
opaque handles                  one pointer word (interop §2)
unique T                        one pointer word
shared T                        one pointer word → control block (§11)
weak T                          one pointer word → same control block
func(...) -> ...  (non-capturing)   one code-pointer word
```

A thin value copies by register move. When Rule 0 (ownership §6.1) says "deep copy," for these types deep copy *is* the register move — the O(data) / O(1) distinction collapses. Exception: `unique T` is thin, but its bare copy is deep (it walks the pointee), which is exactly the cost cliff ownership §8.1 warns about.

### 3.2 Inline aggregates — the sum of their parts

```
struct Point { x, y }           fields laid out in declaration order, padded per ABI
class Widget { ... }            identical layout story to struct (ownership §2)
[N]T fixed arrays               N × sizeof(T), inline, no header
tuples (A, B)                   anonymous struct {A, B}
```

A `class` and a `struct` produce byte-for-byte the same layout for the same fields. The difference between them is entirely front-end (init/deinit, receivers, identity operators) — nothing about a `class` survives to the layout level as an extra word. There is no hidden header, no vtable pointer, because there is no inheritance to dispatch over.

Tuples are anonymous structs and nothing more. `(int32, string)` and a two-field struct with those types are the same bytes. The parens-construct / bare-unbuild rule (foundation §29) is pure syntax: a bare `return a, b` constructs the same physical tuple a parenthesized literal would.

### 3.3 Fat — pointer plus metadata

The fat pointers are where Vertex spends its words:

| Type | Lowered shape | Words | Owns its pointee? |
| --- | --- | --- | --- |
| `string` | `{ptr, len}` → UTF-8 bytes | 2 | yes (value semantics) |
| slice view `buf[0..4]` | `{ptr, len}` | 2 | **no** — borrowed view |
| dynamic array `[]T` | `{ptr, len, cap}` | 3 | yes — the container exception |
| `map[K]V` | `{ptr}` → table header | 1 (fat by proxy) | yes |
| capturing closure | `{code, env}` | 2 | yes — owns `env` |
| `range T` | `{start, end}` | 2 scalars | n/a — no pointer at all |

Two consequences worth stating explicitly:

**Copy depth follows ownership, not width.** A bare owning copy of a `string` or `[]T` copies the header *and* duplicates the payload it points to — that is what "deep" means in ownership §10, and fat pointers are precisely the types where the O(data) cost is real. A transfer copies the header and stops. A slice view is the odd one out: it owns nothing, so copying a view is always two words, and the compiler pins its lifetime inside the lifetime of the buffer it points into.

**`string` is immutable, and the implementation may exploit it.** Semantically a string copy is a deep copy under Rule 0. Because no pathway can ever mutate string bytes, an implementation is licensed to share payloads or intern literals as an optimization — the observable behavior is indistinguishable. This license does *not* extend to `[]T`, which is mutable and must genuinely duplicate on a bare owning copy.

---

## 4. `char` and `string` at the Byte Level

A `char` is a Unicode scalar value in a `uint32` — thin, no allocation. A `string` is a `{ptr, len}` over UTF-8 bytes with no NUL terminator; the terminator is manufactured only at the interop boundary, where `const char*` marshalling appends it (interop §5).

The two iteration forms in foundation §21.4 are the two honest ways to walk that layout: `for c in s` decodes UTF-8 into `char` scalars as it goes (variable stride), while `s.bytes()` strides the raw buffer one `uint8` at a time. Neither allocates; both are loops over the same two-word view.

---

## 5. Fixed Arrays, Dynamic Arrays, and Slices

Three bracket types, three layouts, one rule about who owns what.

**`[N]T`** is inline storage — it lives wherever its enclosing binding or aggregate lives, occupying exactly `N × sizeof(T)` (plus padding). Copying a struct that embeds a `[1024]uint8` copies the kilobyte, inline, as part of the aggregate copy. No pointer exists.

**`[]T`** is the container exception from ownership §2: a three-word header `{ptr, len, cap}` whose backing block is implicitly heap-allocated, because "grow at runtime" cannot be reconciled with fixed frame layout. The *header* obeys Rule 0 like any value; the *block* follows the header's ownership. `push` may reallocate (amortized doubling of `cap`), which is why interior pointers into a dynamic array are not a language concept — only slices with checked lifetimes are.

**`buf[0..4]`** is a `{ptr, len}` view. It is the one foundation type that aliases without owning, and the compiler treats it as a shared-access borrow of the buffer for its whole lifetime: the Law of Exclusivity (ownership §1) forbids mutating or transferring `buf` while a live view into it exists. A view never triggers a deep copy and never runs teardown — it is two words that evaporate.

---

## 6. Maps

A `map[K]V` is a one-word handle to a heap-resident table, owned through the same container exception as `[]T`. The header travels under Rule 0; the table follows it.

`config["debug"] = nil` lowers to an erase call on the table. This is the load-bearing appearance of `nil` in the foundation: **`nil` is not a general value and has no type of its own.** There is no optional type for it to inhabit (foundation §35.1 — absence is an error-tuple, not a null), and no pointer type for it to zero. It is a literal the grammar admits in specific positions, of which map-erase is the canonical one. A Vertex binary contains no null-checking discipline because there is nothing general to be null.

---

## 7. Enums

A unit-only enum **is its discriminant** — `Direction` is an integer of the declared (or default) width, and `Status.Active as int32` is a no-op reinterpretation, not a conversion. Explicit-discriminant enums (foundation §26.4) just pin the values.

A payload-carrying enum lowers to a tagged union:

```
enum Shape { Point, Circle(float32), Rectangle(float32, float32) }

⇒  { tag: uN, payload: union { (), float32, (float32, float32) } }
```

sized to the largest variant plus the tag, laid out per ABI. A `switch` over it reads the tag once and dispatches — dense tags become a jump table, sparse ones a compare chain; either way the case bindings (`case .Rectangle(w, h):`) are views into the payload bytes, not copies, under the loop-default shared access rules. Enum copies are always shallow inline copies of `{tag, payload}` *unless* a variant embeds an owning fat type (a `Text(string)` variant), in which case Rule 0's deep copy recurses into the live variant only — the tag tells the copy routine which payload interpretation to walk.

---

## 8. Functions and Calls — Where the Conventions Meet the ABI

The three parameter conventions (ownership §3) are three physical passing modes. This is the single most important table in this document:

| Signature | What the callee receives | Caller-side lowering |
| --- | --- | --- |
| `x: T` (shared) | read-only view: registers for small trivially-copyable values, else a pointer to the caller's storage | nothing — bare |
| `x: mut T` | the **address** of the caller's `var` slot | nothing — bare; requires an addressable `var` (§2.2) |
| `x: var T` (owning) | the value itself, by value | `.transfer()` → header memcpy; bare → compiler-inserted deep copy, then the copy is moved |

Notes on each:

**Shared** never copies observable state and never permits writes; whether it travels in registers or by pointer is an ABI decision invisible to the program. This is why `let` bindings can be passed shared despite possibly having no address — the compiler picks the mode that fits the value it has.

**`mut`** is literally a pointer parameter. `increment(count)` compiles to `increment(&count)`. This is also the whole mechanism behind interop's "scalar out-param" mapping (interop §5): `mut int32` at the boundary *is* `int32*`, no adaptation layer needed. The exclusivity checks (ownership §5.5, §9) exist to make this pointer unique for the duration of the call, which in turn licenses the backend to keep it in a register inside the callee and spill once.

**`var`** receives ownership by value: for thin types a register, for aggregates a move of the header bytes (possibly via a hidden pointer to a caller-built temporary, per platform ABI — semantically still a move). The bare-copy branch is the one place the *caller's* code grows: the deep copy is synthesized at the call site, then handed off exactly as a transfer would be. `frame.transfer()` itself emits **no code** — it is a marker the liveness checker consumes; the "transfer" is just the ordinary by-value pass, made legal.

**Returns.** A tuple return is a physical tuple: small ones come back in register pairs, large ones through a caller-provided result slot (sret). The error convention rides this for free — `return Model{}, err` is two stores, and the caller's `let m, err =` destructure is two loads. Failure costs the same instructions as success.

**Named arguments** (`add(a: 1, b: 2)`) are resolved at compile time to positional order and leave no trace in the binary. **Variadics** (`msg: ...string`) lower to a slice: the caller builds a stack-local `[N]T` of the arguments and passes a `{ptr, len}` view over it.

---

## 9. Function Values and Closures

Foundation §31–32 define two things that share a spelling and differ by one word.

A **non-capturing** function value is a bare code pointer — one word, directly callable, and the only form that crosses the abstract interface boundary (interop §8), because a C callback slot is one word wide and that's that.

A **capturing** closure is the fat pair `{code, env}`. At creation, each captured binding is **copied by value** into the `env` block (foundation §32 — this is why mutating a capture is a compile error: you'd be writing a private copy, and the language refuses to let that lie compile). The `env` block is owned by the closure value and torn down with it; calling the closure passes `env` as a hidden first argument. Writeback, when you want it, is explicit and honest: take a `mut` parameter and let the *caller* thread the pointer (`run(total, func(n: mut int32) { ... })`), which keeps the mutation in the visible signature instead of hidden capture state.

The boundary rejection is now just arithmetic: `{code, env}` is two words, the foreign slot holds one, and there is no foreign side willing to own `env`. The error is a layout fact wearing a diagnostic.

---

## 10. `defer`, `deinit`, and Scope Teardown

Both features lower to the same thing: straight-line calls emitted at scope exit.

`defer` statements are collected per scope and emitted in **reverse registration order** on every exit edge — normal fall-through, `return`, `break`, `continue`. Because there is no unwinder, "every exit edge" is a finite, statically known set, and the deferred call is duplicated (or jumped to via a landing block) on each one. A `defer` costs exactly the call it defers.

`deinit` runs the same way: when a binding with a `deinit` (directly, or transitively through its fields) reaches the end of its liveness, the compiler emits the deinit call there — fields in reverse declaration order, locals in reverse declaration order. And here §1's third anchor pays off: **a transferred binding simply has its teardown not emitted.** No flag was set, no flag is checked; `.transfer()` moved the end of liveness to the transfer site, and the destination scope inherited the teardown obligation. The compile errors on conditional transfer (ownership §6.7) exist precisely to keep this true — the moment "was it transferred?" becomes a runtime question, Vertex would need drop flags, so the language forbids the question.

---

## 11. The Heap Doors, Lowered

**`unique(Expr)`** is one allocation and one pointer word. Construction is `alloc + move-in`; the owning binding's teardown is `deinit(pointee) + free`. Transfer moves the word; bare copy walks the pointee (deep) into a fresh allocation. There is no header beyond the payload — no count, no metadata — which is why there is no `unique T → weak T` path (ownership §8.1): there is nothing for a weak reference to check.

**`shared(Expr)`** allocates a control block:

```
{ strong: atomic uint, weak: atomic uint, payload: T }
```

The `shared T` handle is one word pointing at it. Copying the handle is an atomic increment of `strong` — this is the "always cheap, never deep" behavior of ownership §8.2, now visible as machine ops. When `strong` hits zero, `deinit(payload)` runs; when `weak` also hits zero, the block is freed. The two-phase teardown is what lets a `weak T` outlive the payload safely.

**`weak(a)`** copies the same block pointer and bumps `weak`. **`.upgrade()`** is an atomic increment-if-nonzero on `strong`: success hands back a fresh strong handle and `""`; failure hands back a zero-value and the error string, which is just the boundary-tuple convention (foundation §35) applied to a race the type system can't statically win. Like `.transfer()`, both `shared()` promotion and `.upgrade()` are compiler-known intrinsics — method-shaped, never dispatched.

**Identity (`===`, classes only)** compares storage addresses: for two `shared T` handles, the control-block pointers; for stack-resident class bindings, the addresses of their slots. It answers "same allocation?", never "same bytes?" — that's `==`'s job, where defined.

---

## 12. Ranges, Loops, and Switch

A range is `{start, end}` — two scalars, no pointer, exclusive by construction (foundation §13). Every loop form in the language lowers to a `while`:

```vertex
for i in 0..5 { body }
      ⇓
var i = 0
while i < 5 { body; i += 1 }
```

Array iteration is the same shape over `{ptr, len}` with a stride of `sizeof(T)`; the shared/`mut`/consuming forms differ only in what the loop variable *is* — a view, a pointer, or a moved-out value whose slot in the (now-dead) container is never touched again. String iteration strides by decoded scalar. Map iteration walks the table in unspecified order. Slicing (`buf[0..4]`) and switch-on-range are the same two scalars used as bounds and as comparison pair respectively — the range type never grows behavior beyond its two words.

---

## 13. Conversions and Casts

`int8(i)`, `float32(i)` and friends, and the `as` operator, lower to the same conversion instructions — truncation, extension, int↔float — chosen by source and destination width. Neither form allocates or calls anything. `enum as intN` is a tag read (§7). There is no dynamic cast, because there is no runtime type information to consult; every `as` is resolved, checked, and lowered at compile time, and an impossible one is a compile error (`Expected(error, "cannot convert string to int32")` — foundation §36.3 tests exactly this).

---

## 14. What a Vertex Binary Does *Not* Contain

Worth ending on the negative space, because it's the point of the design:

| Absent mechanism | Replaced by |
| --- | --- |
| Garbage collector | static liveness + scope teardown (§10), refcounts only where you wrote `shared` |
| Exception unwinder / landing pads | the `(T, string)` tuple, ordinary control flow (§8) |
| Vtables / dynamic dispatch | no inheritance; all calls direct (§3.2) |
| Drop flags | conditional transfer is a compile error (§1, §10) |
| Null-pointer discipline | no general `nil`; absence is an error tuple (§6) |
| Runtime type info | all casts static (§13) |
| Hidden allocation | heap only via `unique`/`shared`/containers, all spelled in source |

Every row is the same trade, made the same direction: a runtime question converted into either a compile-time proof or a visible piece of syntax. `foundation.md` is the syntax; this document is the proof obligations it discharges.