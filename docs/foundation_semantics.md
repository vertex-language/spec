# Vertex Language Reference: Foundation & Data Layout

## Specification 2.2 — Semantics & Rationale

Companion to `foundation.md`, same section numbers. The grammar says
what you can write; this document says what it compiles to — sizes,
layouts, calling conventions, and the runtime cost model. Nothing here
adds syntax.

---

## 0. The Core Model

Four rules generate almost every layout decision below. They're stated
once here so later sections can just cite them.

### 0.1 Thin vs. Fat — extent decides

A handle to a value is **fat** exactly when the value's *extent* (its
length or size) is not part of its static type, and **thin** otherwise.

C gives every pointer the same thin shape and makes the programmer
carry the length in their head. Rust and C++ independently converged on
the fix: pair the pointer with its length for dynamically-sized views
(`&[T]`, `std::span<T>`), keep it thin when the size lives in the type
(`&[T; N]`, `std::array<T, N>`). Vertex adopts the same split
wholesale:

| Type | Extent in the type? | Handle | Precedent |
|---|---|---|---|
| `[T; N]` | yes — `N` | thin | `std::array`, Rust `[T; N]` |
| `[T]` owned | no | fat `{ptr, len, cap}` | `Vec<T>` |
| `[T]` borrowed | no | fat `{ptr, len}` | `&[T]`, `std::span` |
| `string` | no | fat, same as `[uint8]` | `String` / `&str` |
| `cstr` | no — and no length either | thin (deliberate exception) | `const char*` |
| `map<K,V>` | no | one word → heap table | `unordered_map` internals, made official |

There is deliberately **no third option** — no raw thin pointer plus
programmer-tracked length anywhere in user-facing code. That C escape
hatch is the source of an entire vulnerability class, and closing it
costs one machine word per slice.

The fat handle isn't just safety bookkeeping; it's what makes safety
*cheap*. Because `len` rides in a register next to `ptr`, a bounds
check is one compare against a value that's already loaded — and §23.6
shows the compiler deleting even that in the common loops.

One property every handle shares, thin or fat: it is **trivially
movable** — moving any Vertex value is a flat copy of its handle
words, never a user-defined move constructor or a representation
branch. §0.4 explains why; the no-SSO decision under *Strings* is this
rule defending itself.

### 0.2 Layout is unspecified by default

Unless a type opts into a C-compatible layout (§28.4 enums are the one
grammar-level case today), the compiler owns the layout:

- **Fields may be reordered** to minimize padding. A `struct { a: uint8,
  b: int64, c: uint8 }` is 10 bytes of payload and lays out as
  `{b, a, c}` = 16 bytes, not the 24 bytes C's declaration-order rule
  would force. This is Rust's default-`repr` behavior; C and C++ cannot
  do this because their ABI promises declaration order, and it's worth
  a real fraction of cache footprint in ordinary programs.
- **Unused bit patterns are compiler property.** Any bit pattern a type
  can never legally hold — the null pointer of a class handle, values
  ≥ 0x110000 in a `char`, values ≥ 2 in a `bool`, unassigned
  discriminants in an enum — is a **niche** the compiler may spend on
  enclosing types. §25 spends them on optionals; §28 spends them on
  enum discriminants.

The practical consequence: never `memcpy` a Vertex type across an FFI
boundary and expect C to understand it, unless it's one of the
explicitly C-shaped types (`cstr`, explicit-discriminant enums,
scalars). That's the trade, and it's the right one — layout freedom is
where a modern compiler gets its "free" wins.

### 0.3 One ABI rule for aggregates

Any value type at most two machine words (structs, tuples, fixed
arrays, enums, fat handles alike) passes and returns **in registers**.
Anything larger passes by hidden reference and returns via a hidden
out-pointer (`sret`), with the caller providing the slot — the standard
SysV-style split. This is a calling-convention detail the source never
expresses: multi-value returns (§31.6, §37) are just struct returns and
inherit it for free.

### 0.4 Ownership is compile-time — the C++ smart-pointer lineage, minus the runtime residue

The handle shapes above serve the ownership model in `ownership.md`,
whose ancestry is C++'s:

| Vertex | C++ ancestor | Kept | Removed |
|---|---|---|---|
| owning handle (`class`, owned `[T]`, `string`, `map`) | `unique_ptr` / RAII | single owner, `deinit` at scope end, zero cost | the moved-from husk |
| `x&` consume | `std::move(x)` | explicit transfer at the site | optionality — omitting it is a compile error, never a silent copy (Invariant E) |
| `shared(...)` / `shared<T>` | `make_shared` / `shared_ptr` | refcounted multi-ownership, opt-in | per-borrow count traffic (§29.1) |
| bare / `mut` parameter | `const T&` / `T&` | by-reference conventions | aliasing UB — exclusivity is checked (`ownership.md` §9) |

The one divergence that pays for everything else: **Vertex moves are
destructive at compile time; C++ moves are not.** `std::move` leaves a
live "valid but unspecified" object behind — so every `unique_ptr`
destructor branches on null, and every move constructor writes a
tombstone into its source. After `x&`, `x` is statically dead
(`ownership.md` §3.5): no destructor runs on it, nothing reads it, the
compiler proved so.

Three layout consequences fall out:

- **A move is a `memcpy` of the handle.** One to three words copied,
  source forgotten. No move constructors exist; no type may have a
  representation that would need one (this kills SSO — see *Strings*).
- **`deinit` never checks anything.** Moved-from objects don't reach
  destruction, so `unique_ptr`'s per-destructor null branch has no
  Vertex equivalent.
- **Borrows are free.** A bare or `mut` parameter (Invariant A: can't
  be stored, returned, or outlive the call) passes the same words the
  owner holds — no count, no flag, no lifetime tag. §29.1 shows this
  is also what makes `shared<T>` cheap.

So when later sections say a handle is "one word," read it with this
rule attached: that word count is the *total* cost of owning, moving,
and lending the value.

---

## 2. Bindings — `let` and `var`

```vertex
let x = 10
var y = 20
```

One axis, stated on the binding: `let` names a value that cannot be
reassigned **or mutated through this name**; `var` permits both. The
spelling is Swift's; the semantics are Rust's. The three ancestors
split on this design and Vertex takes a side deliberately:

| Model | Immutability lives in… | `let` class ref → mutate field? | Move out of immutable? |
|---|---|---|---|
| C++ `const` | the **type** | n/a (`const` propagates) | no (`const` forbids) |
| Swift `let` | the binding — with a reference-semantics exception | **yes** (only the reference is frozen) | n/a (ARC, no moves) |
| Rust `let` | the **binding**, uniformly | no | **yes** |
| **Vertex `let`** | the **binding**, uniformly | **no** | **yes** |

### 2.1 What `let` forbids — the four faces of one rule

A `let` binding rejects every path that would mutate the value it
names:

- **Reassignment** — `x = 11` is a compile error.
- **Field/element mutation** — `p.x = 0`, `items[0] = 9`,
  `config["k"] = 1` are compile errors through a `let`.
- **`mut` borrows** — `rename(mut w, ...)` requires `w: var`. The
  exclusivity checker (`ownership.md` §9) needs one static source of
  truth for who may mutate; binding mutability is that source.
- **Mut-receiver methods** — `p.reset()` on a `let p` is a compile
  error, since `func (p: mut Point) reset()` is a `mut` borrow of the
  receiver.

The rule is **uniform across structs and classes** — the one deliberate
divergence from Swift. Swift lets you mutate properties through a
`let` class reference because under ARC the *handle* is the value and
only the handle is frozen. Vertex's handle is an §0.4 *owning* handle:
the object behind it has exactly one owner, so mutability of the object
coherently flows through the owner's binding. Making classes an
exception would also punch a hole in exclusivity checking — a `let`
that can still mutate is a `let` the checker can't trust.

### 2.2 What `let` permits — consumption

```vertex
let w = Widget(1)
archive(w&)          // legal: move out of a `let`
let s = shared(w2&)  // legal: promotion consumes a `let` too
```

Moving is not mutation. `w&` never modifies the value — it transfers
the handle words and **kills the binding** (`ownership.md` §3.5), and
a dead name has no immutability left to violate. This is Rust's
position, and it's load-bearing: if `let` forbade consumption, a `let`
value could never be archived, promoted to `shared` (§6.4), or
returned by move — and every owning value would drift toward `var`
just to stay usable, hollowing `let` out. Read `let` as "no one
mutates this value through this name," not "this name lasts forever."

Bare (read) borrows are of course always legal from either binding
form.

### 2.3 Receiver exemption from the call-site sigil

`ownership.md` §8 requires `mut` at the call site for mut parameters —
mutation must be visible where it happens. Method receivers are the
one exemption: `p.reset()` writes no sigil, but requires `p` to be a
`var`. The sigil rule exists to make the mutated argument findable
among many; the receiver is singular, fronted, and named in the
method's signature, so the information the sigil carries is already at
the site. This is Swift's `mutating` convention, and it ratifies §27's
grammar as written.

### 2.4 No same-scope shadowing

Redeclaring a name in the same scope is a compile error; inner scopes
shadow outer ones per ordinary lexical scoping. Rust allows same-scope
shadowing largely to serve transform chains (`let x = ...; let x =
parse(x);`) where each stage invalidates the last — but Vertex's `&`
already renames on move (`var a = w&`), so the idiom shadowing exists
to serve has a first-class spelling. Two live meanings for one name in
one scope buys nothing here and costs reading confidence.

### 2.5 Runtime cost: none, by construction

`let` vs. `var` is a compile-time fact about the binding with **zero
runtime representation** — same words, same layout, no flag — exactly
as §23.4 says of `mut [T]`. `let` does not mean "compile-time
constant": it enables constant propagation when the initializer is
foldable but guarantees nothing. There is no `const_cast`, no
`mutable` escape hatch, and no UB for the optimizer to reason around —
which is precisely what lets it trust a `let` completely.

---

## 1, 3–16. Scalars, Arithmetic, and Defined Behavior

The scalar types are exactly their names: `intN`/`uintN` are two's
complement at the stated width, `int`/`uint` are the pointer width,
`float32`/`float64` are IEEE 754 binary32/64, `bool` is one byte
holding 0 or 1, and `char` is a Unicode scalar value in four bytes
(valid range `0..0xD7FF` ∪ `0xE000..0x10FFFF` — note the niches).

Two semantic decisions worth stating because C leaves both undefined:

- **Overflow is defined, and the default is loud.** The plain operators
  `+ - *` **trap on overflow in every build mode** — the Swift model,
  not the C model (undefined behavior) and not the Rust release-mode
  model (silent wrap). On modern hardware the check is nearly free: the
  flags are already set by the arithmetic, so it compiles to the
  arithmetic instruction plus a never-taken branch. The grammar's `&+
  &- &*` (§10) are the explicit wrapping forms for the hashing/DSP/
  checksum code that genuinely wants modular arithmetic — matching
  Swift's `&+` and Rust's `wrapping_*`, spelled as operators. Silence
  never means "wraps"; wrapping is always visible at the site.
- **Conversions are total.** `float64 as int32` (§6.1) saturates on
  out-of-range and produces 0 from NaN (Rust's defined `as` semantics
  since 1.45), rather than C's UB. Integer narrowing truncates
  two's-complement style. Every `as` between numeric types has one
  defined answer for every input.

`..`/`..=` ranges (§13) are ordinary two-field structs `{start, end}`
— they have no runtime story beyond §31's.

On spelling: the wrapping operators `&+ &- &*` and the consume sigil
`&` share a glyph but never a position — wrapping forms are always
infix, consume is always postfix on a name — so there is no ambiguity.

---

## 23. Arrays

### 23.1 Fixed Arrays — value type, thin, often never in memory at all

```vertex
var coords: [int32; 3] = [10, 20, 30]
```

`[T; N]` is `N` contiguous `T`s with no header — a C array's layout
with `std::array`'s semantics: it's a real value, so assignment copies
all `N` elements and there is no decay-to-pointer. Under §0.3 a small
fixed array passes in registers; SROA in the backend routinely
dissolves small fixed arrays into scalars so they never touch the stack
at all.

Indexing with a constant is checked at compile time (out-of-range is a
compile error, not a runtime trap). Indexing with a runtime value is a
single compare against the literal `N` — an immediate, not a load,
because `N` lives in the type.

### 23.2–23.4 Dynamic Arrays — owned fat triple, borrowed fat pair

```vertex
var items: [int32] = []
items.push(42)
```

An owned `[T]` is the three-word `{ptr, len, cap}` from §0.1 pointing
at one heap buffer — mechanically `Vec<T>` (deliberately not
`std::vector`, which also drags an allocator handle Vertex doesn't
expose). Growth is amortized geometric (target factor ~1.5–2×; a
library guarantee, not a grammar one). An empty literal `[]` allocates
**nothing** — `ptr` is a dangling-but-aligned sentinel and `cap` is 0,
so cheap-to-create empty arrays are actually cheap (the `Vec::new`
trick).

The triple is an owning handle in §0.4's sense — the `unique_ptr` side
of the family: one owner, buffer freed at scope end, transferred with
`items&` as a three-word `memcpy`. Contrast `std::vector`'s move
constructor, which must null out its source so the source's destructor
finds a husk; Vertex writes no husk, because after `items&` the source
is statically dead.

Passing `[T]` bare — a borrow, per `ownership.md` §1 — hands across
only the two-word `{ptr, len}` pair. `cap` is owner-only information:
a reader has no business seeing it, and dropping it is what lets one
borrowed slice type view an owned array, a fixed array, or a
sub-range uniformly (same reasoning as `&[T]` / `std::span`). The
*shape* of the borrow is §0.1's business; its *safety* — no count, no
lifetime tag, can't escape — is §0.4's Invariant A.

`mut [T]` is the same two words; mutability is a fact about the
*binding and the signature* (the `mut` convention from `ownership.md`
§2, and the binding rules of §2 above), never a runtime bit next to
the data.

### 23.6 Where the bounds checks go

The checks exist in the semantics and mostly not in the binary:

- `for x in items` (§22) compiles to pointer-increment iteration with
  **zero** per-element checks — the loop bound *is* `len`, so there is
  nothing left to verify.
- Ordinary range analysis erases checks whose index is already
  dominated by a comparison (`if i < items.length { items[i] }`).
- What remains — genuinely unpredicated random access — costs one
  compare-and-never-taken-branch against a `len` already in a register,
  courtesy of the fat handle. This is the modern consensus (Rust, Go,
  Swift all ship it): the safety tax on real programs is measured in
  fractions of a percent, and the language doesn't offer an unchecked
  index to claw it back.

---

## Strings

`string` is byte-for-byte the `[uint8]` layout — `{ptr, len, cap}`
owned, `{ptr, len}` borrowed — plus one invariant enforced at every
mutation boundary: the bytes are valid UTF-8. Rust's exact design
(`String` = `Vec<u8>` + invariant), chosen over two tempting
alternatives:

- **No small-string optimization.** C++'s SSO stores short strings
  inline in the handle, which buys locality for short strings and costs
  everything else: every operation branches on the representation, and
  `string` would stop degrading to `[uint8]` for free. Decisively, SSO
  is the canonical type that *needs* a move constructor —
  `std::string`'s move must branch on the mode and fix up the
  self-pointing buffer — and §0.4 offers no move constructors. One
  representation, trivially movable, byte-view at zero cost.
- **No UTF-16/UCS-2 legacy.** Indexing a `string` by integer is not
  O(1) code-point access and the language doesn't pretend it is;
  iteration is by `char` (decoded scalar) or by byte via the `[uint8]`
  view.

`cstr` stays the deliberate exception from §0.1: thin, borrowed,
foreign-owned, nul-terminated by C's convention, and **not** UTF-8
validated. `.c_str()` reuses an already-terminated buffer when it can
and materializes a temporary nul when it can't. It exists so the FFI
boundary is one visible type, not a convention smeared across every
binding.

---

## 24. Maps

```vertex
var config: map<string, int32> = {}
```

`map<K,V>` is a single word pointing at a heap table — the indirection
every serious hash map already has internally, promoted to the entire
representation so the handle stays one word and moves trivially. That
word is a §0.4 owning handle: single owner, freed at scope end,
transferred with `config&` as a one-word copy.

The table itself is specified as behavior, not layout, but the intended
implementation is worth naming because it's a solved problem:
**open-addressed, SwissTable-style** — one byte of control metadata per
slot, probed 16 slots at a time with SIMD, entries stored inline in the
slot array. This is what Rust's `HashMap` (hashbrown), Abseil's
`flat_hash_map`, and Go's runtime map (since 1.24) all converged on,
and it beats the chained-buckets design `std::unordered_map` is
ABI-frozen into on every axis that matters: one allocation instead of
one per node, no pointer chase per lookup, and cache-line-friendly
probing.

Two semantic guarantees ride on top:

- **Iteration order is unspecified and deliberately perturbed** across
  runs (Go's discipline), so no program can accidentally depend on it.
- **The hash is seeded per-process** with a keyed hash (SipHash-class)
  for string-like keys — HashDoS resistance is a default, not an
  option.

`config["debug"] = nil` (§24) is ordinary deletion. Whether the
implementation uses tombstones or backward-shift is invisible in the
semantics — implementation freedom, stated once.

---

## 25. Optionals — niches everywhere they exist, a tag only where they don't

```vertex
var maybe: int32? = nil
var animal: Animal? = nil
```

One syntax, two layouts, chosen per-`T` at compile time — exactly the
choice Rust's compiler makes for `Option<T>`, and Vertex generalizes it
using §0.2's niche rule:

- **`T` has a niche → `T?` is the same size as `T`.** `nil` occupies a
  bit pattern `T` can never hold. This covers far more than pointers:
  class handles (null), `shared<T>` (null), `[T]` and `string` (null
  data pointer), function values (null code pointer), `bool` (byte
  value 2), `char` (any surrogate), and any enum with spare
  discriminant values. `Animal?`, `string?`, `func(int32)->int32?` are
  all **zero-overhead**. The owning handles have that null niche
  *because* of §0.4: destructive moves mean no live handle is ever
  null — there is no moved-from state that needs the zero pattern.
  C++ can't make this trade; `unique_ptr` spends null on "moved-from."
- **`T` has no niche → tag byte + payload.** An `int32` uses all 2³²
  patterns, so `int32?` is a two-variant tagged union (§28), padded to
  alignment: 8 bytes for `int32?`, not 5.

The programmer-visible contract is only `if let val = maybe` — which
layout was chosen is knowable (`sizeof(T?) == sizeof(T)`) but never
needs knowing. Nesting stays coherent for free: `Animal??` uses the
null niche for the *inner* `nil` and a second forbidden pattern or a
tag for the outer one, so the three states remain distinct without any
special case — the same mechanism that lets Rust flatten
`Option<Option<&T>>`.

---

## 26 / 29. Structs vs. Classes — the value/reference axis, and nothing else

```vertex
struct Point { x: int32, y: int32 }   // value type
class Animal { name: string }          // reference type
```

The two constructs exist to express one representational fork; methods,
fields, and init syntax are common to both on purpose.

- **`struct`** is an inline value: assignment copies it field-by-field,
  it has no identity, no header, no allocation. Layout follows §0.2
  (reorderable, padded to alignment). Under §0.3 small structs live in
  registers; SROA frequently dissolves them entirely.
- **`class`** is a heap allocation behind a **single-word, never-null
  handle**. Assignment moves the handle per the ownership rules, never
  the payload — which is why identity (`===`/`!==`, §15) exists only
  for classes: two handles can name the same object, a question that's
  meaningless for structs. The handle's null pattern is a niche (§25),
  so `Animal?` costs nothing.

**Classes are RAII, C++-style, with the runtime residue removed.**
The `init`/`deinit` pair is the constructor/destructor pair; resource
lifetime is object lifetime; cleanup is scope-driven, never manual.
Mechanically a plain `class` value is a `unique_ptr<T>` minus the
husk (§0.4): same single word, same single-owner discipline, same
deterministic destruction at the owner's scope end — but where
`unique_ptr` earns those properties with a runtime null state (set by
every move, tested by every destructor), Vertex earns them statically.
`a&` transfers the word and kills the name; `deinit` runs exactly once
with no null check; use-after-move is `ownership.md` §3.5's compile
error rather than a silent null deref. RAII with double-free and
use-after-free ruled out by the compiler instead of programmer
discipline. There is no tracing GC, and — unlike Swift — no
per-assignment retain/release traffic on plain classes.

The split mirrors Swift's struct/class distinction rather than C++'s
storage-based one: the declaration states value-vs-reference
*semantics*, and storage location (stack, register, inlined into a
containing object) is always the compiler's call.

### 29.1 `shared<T>` — the `shared_ptr` half of the lineage, on a diet

```vertex
var a = shared(Widget(1))
```

`shared(...)` (`ownership.md` §6) is the opt-in second cardinality:
refcounted multi-ownership, semantically C++'s `shared_ptr`. Three
decisions keep it cheaper than its ancestor:

- **One word, not two.** `shared_ptr` is two words to support separate
  control blocks, aliasing constructors, and `weak_ptr`. Vertex's only
  construction path is `shared(...)` — the `make_shared` discipline
  made mandatory — so the count is always co-allocated with the
  object, and the handle is one word pointing at the pair. The cases
  that force `shared_ptr` fat are simply not expressible.
- **The count moves only on duplication.** Borrows are §0.4's story: a
  bare or `mut` parameter of `shared<Widget>` passes the same one word
  with **no increment** — where `shared_ptr` by value bumps the count
  twice per call, and Swift retains on nearly every assignment.
- **Moves stay free.** `shared(u&)` — promotion (`ownership.md` §6.4)
  — and `s&` between shared bindings are one-word copies with no count
  traffic: a move changes which name owns the +1, not how many owners
  exist. C++ gets this only if the programmer remembers `std::move`
  and silently pays a refcounted copy if they forget; Invariant E
  makes forgetting a compile error.

The word's null pattern is a niche, so `shared<Widget>?` is one word
too (§25). `shared<Widget>` and `Widget` remain distinct types with no
implicit conversion (`ownership.md` §6.5).

---

## 28. Enums — tagged unions with the tag optimized away when possible

```vertex
enum Shape {
    Point,
    Circle(float32),
    Rectangle(float32, float32),
}
```

The baseline lowering is the standard tagged union — a discriminant
plus payload storage sized to the largest variant — same as Rust's
`enum` and a disciplined C `{tag; union}`. On top of that baseline the
compiler applies, in order:

1. **Discriminant sized to fit.** Three variants need one byte, not an
   `int`.
2. **Discriminant placed in padding** of the largest variant when
   alignment left a hole — often making the tag free in space.
3. **Discriminant elision via niches.** If some variant's payload has
   forbidden bit patterns (a class handle, a `string`'s pointer, a
   `char`), unit variants can *be* those patterns and the separate tag
   disappears entirely. `enum Tree { Leaf, Node(BoxedNode) }` is one
   word. This is the same machinery as §25 — `T?` is literally the
   two-variant special case of this rule.

The cost model to keep in mind is `std::variant`'s: the whole enum is
one fixed size (max over variants, plus tag if not elided), so a unit
variant sitting in an array costs as much as the fattest variant.
That's the price of storing enums inline without indirection; when one
variant is much larger than the rest, box it behind a `class` and the
niche rule usually hands the tag back for free.

**Explicit-discriminant enums (`enum Status : int32`) are the escape
into C.** When every variant is a unit variant with a declared backing
type, the enum *is* that integer — no payload, no union, guaranteed
layout, and `as int32` (§28.4) is a zero-cost reinterpretation rather
than an extraction. This is the one grammar-level opt-out from §0.2's
layout freedom, and therefore the correct enum form at any FFI
boundary. The one obligation it creates sits on the *inbound*
direction: an arbitrary `int32` is not a `Status`, which is exactly why
the grammar routes that conversion through a function returning
`Status?` (§28.4's `statusFromInt`) instead of a cast.

---

## 31. Tuples — anonymous structs, one story not two

```vertex
let t: (int32, string) = (1, "a")
```

A tuple is an anonymous struct: same value semantics, same §0.2
reorderable layout, same §0.3 registers-or-sret ABI. `.0`/`.1` and
named tuple fields are two spellings of the same constant-offset field
access a named struct gets from `.x`. Nothing about tuples exists at
runtime that doesn't exist for structs — which is why multi-value
returns (§31.6) required no design: returning `(int32, int32)` *is*
returning a struct, and small ones come back in a register pair.

---

## 33 / 34. Function Values — the §0.1 rule applied to code

```vertex
let on_event: func(int32) -> int32 = free_fn          // thin
let counter  = func() -> int32 { return base + 1 }    // fat if capturing
```

Same extent rule, applied to code: what varies between function values
isn't a length but an *environment size*, and the type erases it.

- **Non-capturing** function values have no state beyond a code
  address: one word, bit-compatible with a C function pointer, zero
  call overhead beyond the indirect jump.
- **Capturing** closures are the two-word fat value `{code_ptr,
  env_ptr}`. The call site can't know the environment's size (the type
  erased it), so the environment can't ride in the value — it moves
  behind the pointer and the handle stays two fixed words no matter
  what's captured. Same shape, same reason, as every type-erased
  closure representation.

Captures are **by value at creation** (§34's stated semantics —
`factor` is copied, mutating a capture is a compile error), which makes
the environment a plain immutable struct: no capture-lifetime analysis,
no closures-borrowing-locals hazard, and the env struct's layout gets
§0.2's treatment like anything else. A closure that owns a heap
environment is one more §0.4 owning handle — transferred with `f&` as
a two-word copy, env freed at the owner's scope end.

Two backend refinements the model admits, both worth implementing:

- **Inline environments.** When the captures fit in one word (`int32`,
  a `char`, a small struct), pack them *into* the `env_ptr` slot
  directly — a one-word capture then costs no allocation at all.
  `sizeof` and ABI don't change; only the interpretation of word two
  does, and the closure's own code (which is the only reader) knows
  which it got.
- **Stack environments for non-escaping closures — free, courtesy of
  Invariant A.** A closure passed as a bare (borrowed) parameter
  cannot, by `ownership.md`'s Invariant A, be stored or outlive the
  call. That is exactly Swift's `@noescape` guarantee — except Vertex
  gets it from the ownership rules instead of an attribute. The caller
  can therefore build the environment on its own stack and hand across
  a pointer to it; the heap allocation only exists when a closure is
  *consumed* (`f&`) or stored, i.e., when it actually escapes. The
  common `process(nums, func(n) { ... })` pattern compiles with zero
  allocations.

---

## 37. Error Handling — no unwinding machinery, just the ABI you already have

```vertex
func parseInt(s: string) -> (int32, string) { ... }
let n = parseInt(s: s)?
```

The convention returns `(T, error)` tuples — which §31 already made
plain struct returns, so the "error handling runtime" is: nothing.
No unwind tables, no landing pads, no invisible control flow, no
codepaths that only execute during exceptions and never get tested.
Errors travel in registers like any other small struct, and every
propagation edge is in the source.

`?` (§37.4) is pure sugar with a fixed lowering: destructure, test the
error against its empty value, early-return the error through the
current function's own `(T, error)` shape on failure, yield the value
on success. `if let` / `else ->` (§37.5–37.6) are the same test with
both arms in view. `defer` (§30) composes with all of this the RAII
way: deferred cleanup and `deinit`s run on the early-return path
exactly as on the normal one, because the early return *is* a normal
return — and per §0.4, none of those `deinit`s carry a moved-from
check on any path.

---

## Summary Table

| Construct | Handle | Where it lives | Notes / precedent |
|---|---|---|---|
| `let` / `var` binding | — | — | compile-time fact, zero runtime representation (§2); `let` = no reassign/mutate/`mut`-borrow, move-out **legal**; Rust semantics, Swift spelling |
| `[T; N]` | thin, value | stack / registers / inline | `std::array`; const-index checked at compile time |
| `[T]` owned | fat `{ptr,len,cap}` | heap | `Vec<T>`; owning handle, moved by `&` (§0.4); empty = no allocation |
| `[T]` borrowed | fat `{ptr,len}` | — | `&[T]` / `span`; cap is owner-only; free via Invariant A |
| `string` | same as `[uint8]` + UTF-8 | heap | no SSO — must stay trivially movable (§0.4) |
| `cstr` | thin, foreign | C-owned | the one deliberate exception |
| `map<K,V>` | 1 word → table | heap | SwissTable; seeded hash; owning handle per §0.4 |
| `T?`, `T` has a niche | same size as `T` | same as `T` | pointers, handles, bool, char, sparse enums |
| `T?`, no niche | tag + payload | same as `T` + align | `Option<i32>` shape |
| `struct` / tuple | inline value | stack / registers / inline | fields reorderable (§0.2) |
| `class` | 1 word, non-null | heap | RAII; `unique_ptr` minus the husk (§0.4); `deinit` never null-checks |
| `shared<T>` | 1 word, non-null | heap, count adjacent | `shared_ptr`/`make_shared` lineage (§29.1); count untouched by borrows and moves |
| `enum` (payloads) | tag + max payload | inline | tag sized-to-fit, hidden in padding, or elided |
| `enum : T` (unit) | just `T` | inline | guaranteed layout — the FFI enum |
| `func` non-capturing | thin, 1 word | — | C-fn-pointer compatible |
| `func` capturing | fat `{code, env}` | env: heap, stack if non-escaping, or inline if 1 word | Invariant A = free `@noescape` |
| `(T, error)` returns | struct return | registers / sret | no unwinding anywhere |