# Vertex Language Grammar

## Grammar — Memory (`typed_ptr` & Pointer Arithmetic)

---

## 0. No Import

`typed_ptr`, and every primitive that operates on it, is core grammar — the same tier as `sizeof`, `alignof`, `reinterpret`, and `&`. There is no package to import and no namespace prefix anywhere in this file.

```vertex
// no import line — new/delete/resize/copy/zero/addr are always in scope
var p: typed_ptr int32
```

---

## 1. The Pointer Type

```vertex
var p: typed_ptr int32
```

`typed_ptr T` is the raw, last-resort pointer — no ownership tracking, no refcount, no compiler discipline. `ownership.md` never governs it (§7/§8 of that spec are explicit on this point).

**Ownership status, spelled out.** A `typed_ptr T` is a thin value (foundation_spec §3.1): bare copy is a register move of the address word, `.transfer()` on it is legal but a no-op beyond ordinary liveness marking (there is no payload for the copy/transfer distinction to distinguish), and **no teardown is ever emitted** for a `typed_ptr` binding going dead — the pointee's lifetime is entirely the programmer's problem, via `delete` (§11.2). Copying a `typed_ptr` never duplicates the pointee; two copies are two aliases, unchecked. This is the one type in the language where the Law of Exclusivity (ownership §1) is a convention rather than a proof.

---

## 2. Address-of / Dereference — both stay `&`

Direction is inferred from the operand's type: `&` on an ordinary value takes its address; `&` on a `typed_ptr T` dereferences it. This is the one symbolic operation retained on `typed_ptr` beyond comparison (§5) — its contract never varies (read or write through a live, aligned, initialized `T`), so there is nothing a method name would disambiguate. Every operation that *computes a new address* instead of reading/writing through an existing one is a method, not a symbol — see §3 and §6.

```vertex
var x: int32 = 42
let p = &x          // address-of  — int32 -> typed_ptr int32
let v = &p          // dereference — typed_ptr int32 -> int32
&p = 99             // dereference on the write side — writes through p
```

**Generic bodies.** Inside a generic declaration, `&x` where `x`'s type is a type parameter `T` is **always address-of**, at every instantiation — including `T = typed_ptr U`. The direction rule keys on the *statically written* type, and a bare type parameter is not spelled `typed_ptr`. A generic body that needs to dereference must constrain or accept `typed_ptr U` explicitly in the signature, at which point the operand's written type is a `typed_ptr` and `&` dereferences as normal. The meaning of a source line never flips per instantiation.

### 2.1 `addr` — Address of a Pointer

The `&`-by-operand-type rule leaves one thing unspellable: the address *of* a `typed_ptr` binding itself (`&p` already means dereference). The `addr` builtin fills exactly that hole, and nothing else:

```vertex
func addr[T](p: typed_ptr T) -> typed_ptr (typed_ptr T)
```

```vertex
var p: typed_ptr int32 = nil
let pp = addr(p)              // typed_ptr (typed_ptr int32) — points at the slot holding p
&pp = someOther               // writes a new address into p, through pp
```

* `addr` requires an addressable operand — a `var` binding or a field path, same rule as passing to a `mut` parameter (foundation_spec §2.2). `addr` of a `let`, a temporary, or an expression is a compile error.
* `addr` exists **only** for `typed_ptr` operands. On any other type, `&x` already means address-of, and `addr(x)` is a compile error with a fix-it pointing at `&`.
* This is the honest spelling for a foreign `T**` out-param that the boundary tuple (interop §3) doesn't absorb — the residue case, matching `typed_ptr T`'s own status as the residue of interop §5.

Deeper nesting composes the obvious way (`addr(pp)` is `typed_ptr (typed_ptr (typed_ptr T))`); each `&` on the result peels one level.

---

## 3. Arithmetic — Methods, Scaled by `sizeof(T)`

Computing a new address is exactly the operation whose bounds contract is easy to get wrong, so it is spelled as a named method rather than an operator — the method name is the place the reader's eye catches it, and the place a doc comment or tooltip can carry the contract from §3.1. There is no operator form; `+`, `-`, `+=`, `++`, `--` do not exist on `typed_ptr T`.

```vertex
let p2 = p.add(1)
let p3 = p.sub(4)
p = p.add(1)
p = p.sub(1)
```

There is no increment/decrement method — `p++` / `p--` are gone entirely, not renamed; write `p = p.add(1)` instead.

### 3.1 Bounds Are Computed, Not Checked

`.add`/`.sub` compute an address; they do not check one. `p.add(n)` is legal to *evaluate* even when the result lands outside the block `p` points into — exactly one exception: the address one element past the last valid one is a legal value to *hold* (needed for end-of-range loops), but not to dereference. Forming any address further out, or dereferencing (`&`, `.at`/`.setAt`, `copy`/`zero` past the block's extent) an out-of-bounds pointer, is undefined — the same undefined-not-a-compile-error status as a stale `delete` (§14). The compiler proves nothing about `typed_ptr` bounds; that is the entire tradeoff of reaching for `typed_ptr` over `[]T` (interop §5).

---

## 4. Pointer − Pointer

```vertex
let n: int64 = p2.diff(p)
```

`p2.diff(p)` yields the element count (not byte count) from `p` to `p2`, signed.

**Same-block contract.** `.diff` is defined only when both pointers address the same allocated block (from one `new`/`resize`, one `&x`, or one array's backing storage), including either one sitting at the block's one-past-the-end address (§3.1). Subtracting pointers into unrelated blocks is undefined — same status as out-of-bounds arithmetic, deliberately matching the machine model this lowers to (foundation_spec §1). Like §3.1, nothing checks this; the method name is where the contract hangs, not where it's enforced.

---

## 5. Comparison — Stays Symbolic

Comparing addresses never dereferences, so there is no unsafety to flag — comparison keeps ordinary operators, unlike §3 and §6.

```vertex
p == p2
p != p2
p <  p2
p <= p2
p >  p2
p >= p2
```

Equality (`==`, `!=`) is defined for any two `typed_ptr T` of the same `T`, including against `nil` (§13). **Ordering** (`<`, `<=`, `>`, `>=`) carries the same same-block contract as `.diff` (§4): ordering pointers into unrelated blocks is undefined, and ordering against `nil` is a compile error — `nil` participates in equality only.

---

## 6. Indexing — Methods, Not Sugar

Indexing is arithmetic-plus-dereference, so it follows §3, not §2: it is a method pair, not bracket sugar.

```vertex
let x = p.at(3)      // read  — equivalent to &(p.add(3))
p.setAt(3, 9)         // write — equivalent to &(p.add(3)) = 9
```

---

## 7. Casting — `as`

```vertex
let raw:  typed_ptr uint8 = p as typed_ptr uint8   // reinterpret
let addr: uint64           = p as uint64            // pointer -> integer
let back: typed_ptr int32  = addr as typed_ptr int32 // integer -> pointer
let auto: typed_ptr uint8  = p                       // target known — `as` inferred
```

`as` never touches memory — it is a static reinterpretation of the address's type, not a read or write — so it stays symbolic like comparison (§5), regardless of how unrelated `T` and `U` are: `typed_ptr T as typed_ptr U` is always legal for any `T`, `U`, the same way `p as typed_ptr uint8` above is.

---

## 8. Casting a Foreign Handle — `abstract` → `typed_ptr T`

An `abstract` handle (interop §2) is a distinct type from `typed_ptr T` — no arithmetic, no dereference, no stride. A cast between the two is legal only in one direction, and only under one condition.

**Legal — memory-flat classification only.** The library's ABI classification (interop §1) decides this: C and WASM imports are memory-flat, meaning the handle is already an address into linear memory. Casting it to `typed_ptr T` is an ordinary reinterpretation, same as any other `as`:

```vertex
// sdlWindowHandle: SDL_Window, minted by a memory-flat (C) import
let raw: typed_ptr uint8 = sdlWindowHandle as typed_ptr uint8
```

**Illegal — object-graph classification.** Objective-C and JS imports are object-graph: the handle is a runtime object reference with no byte representation for Vertex to point at.

```vertex
// nsViewHandle: NSView, minted by an object-graph (Objective-C) import
let raw = nsViewHandle as typed_ptr uint8
// error: `NSView` is an object-graph handle (Objective-C) —
//        no byte representation to reinterpret
```

**No return path.** There is no cast from `typed_ptr T` back to `abstract`. Minting an `abstract` handle is the foreign library's job — a constructor or factory call at the boundary (interop §4.2–§4.3) — never a client-side reinterpretation of an arbitrary pointer.

**Nominal typing still applies.** Each `abstract` alias is distinct (interop §2); a cast off of one memory-flat handle says nothing about another. `SDL_Window as typed_ptr uint8` being legal doesn't make some unrelated memory-flat `abstract` type interchangeable with it — the cast targets `typed_ptr T`, not another `abstract` type.

---

## 9. `reinterpret()` — when the target can't be inferred

```vertex
let bytes = reinterpret(uint8, p)
let back  = reinterpret(Widget, bytes)
```

---

## 10. `sizeof` / `alignof`

```vertex
let s  = sizeof(int32)     // 4
let a  = alignof(int32)    // 4
let s2 = sizeof(Widget)
```

---

## 11. Allocation — `new` / `delete` / `resize`

Three bare, generic builtins handle allocation. Each is an ordinary fallible call under the boundary-tuple convention (foundation §35) where it returns one — nothing here is a `var` parameter, nothing accepts `.transfer()`, and the compiler enforces none of the discipline described below. It is manual, exactly like the pointer arithmetic in §3.

### 11.1 `new[T]` — Allocate

```vertex
func new[T](count: uint64) -> (typed_ptr T, string)
func new[T](count: uint64, align: uint64) -> (typed_ptr T, string)
func new[T](count: uint64, zero: bool) -> (typed_ptr T, string)
func new[T](count: uint64, align: uint64, zero: bool) -> (typed_ptr T, string)
```

Allocates space for `count` contiguous values of `T` (`count * sizeof(T)` bytes).

**Zeroed by default.** A block from `new` starts as `count * sizeof(T)` zero bytes unless you ask otherwise. `zero: false` opts out and hands back memory whose contents are unspecified.

```vertex
let buf, err = new[uint8](1024)              // zeroed — the default
if err != "" {
    panic("allocation failed: " + err)
}
defer delete(buf)

buf.setAt(0, 0xFF)
```

This is the one place in `typed_ptr`'s surface where the language declines to be maximally raw, and it is a deliberate exception to the cost-transparency rule (ownership §10.3 — cheap is silent, expensive is visible). The reasoning is the one that rule itself gives: **when both mistakes are silent, the default goes to the safe one.** Forgetting `zero: false` costs a memset the optimizer can often see through. Forgetting `zero: true` — under the old polarity — cost a garbage read, and garbage reads out of a fresh allocation are how the previous tenant's bytes escape. Ownership §10.3 already accepted a silent O(data) deep copy on a bare call site for exactly this reason ("nothing you don't write can kill your binding"); a silent memset on a *fresh, unread* block is a far smaller price than the one that rule already agreed to pay.

The cost is also smaller than it reads. For any allocation large enough to come from fresh pages, the operating system has already zeroed them — it must, for the same disclosure reason — so the memset collapses to nothing. It is real only for small blocks recycled off a free list, which are a few cache lines you are about to touch anyway.

**`zero: false` — the opt-out.** Reach for it when every byte is provably overwritten before it is read: a container's growth path, a buffer handed straight to a foreign call that fills it, a scratch block reused under a length discipline.

```vertex
// Vector.grow — push() only ever writes below `length`, so nothing
// in the fresh tail is readable before it is written.
let raw, err = new[T](newCapacity, zero: false)
if err != "" { panic("OOM: " + err) }
```

`zero: false` is a claim, not a hint: reading a byte of an unzeroed block before writing it is undefined, the §3.1 rule applied to initialization rather than to bounds. Nothing checks it.

**`align`** guarantees the block starts on an `align`-byte boundary instead of whatever `alignof(T)` would naturally give it. `align` must be a power of two; violating that is an allocation failure (`nil`, non-empty string), not a distinct diagnostic.

```vertex
let simdBuf, err = new[float32](16, align: 32)   // 32-byte aligned, zeroed
if err != "" { panic("aligned alloc failed: " + err) }
defer delete(simdBuf)
```

`align` and `zero` combine — an aligned block that skips the memset is one call:

```vertex
let simdScratch, err = new[float32](16, align: 32, zero: false)
if err != "" { panic("aligned alloc failed: " + err) }
defer delete(simdScratch)
```

**Overflow.** A `count` whose byte size (`count * sizeof(T)`) would overflow `uint64` is an allocation failure (`nil`, non-empty string) — the same failure channel as exhaustion, not undefined behavior, because `new` is the one place the size is computed under the language's control rather than the programmer's (contrast §12).

**Inference.** `T` may be written explicitly (`new[uint8](...)`) or inferred from the declared type of the binding it flows into, following the same inference precedent as `as` (§7):

```vertex
var buf: typed_ptr uint8
buf, err = new(1024)   // T inferred as uint8 from `buf`'s declared type
```

On success the string is `""`. On failure the pointer is `nil` (§13) and the string carries a message such as `"out of memory"`.

### 11.2 `delete` — Release

```vertex
func delete[T](p: typed_ptr T)
```

Releases a block previously returned by `new` or a successful `resize`. `T` is inferred from `p`. `delete(nil)` is a no-op. Deleting anything else — a pointer derived from `&x` (§2), a pointer already deleted, or one offset from its original address (§3) — is undefined, the same way it is in the machine model this language lowers to (foundation_spec.md §1).

```vertex
delete(buf)
```

### 11.3 `resize[T]` — Resize

```vertex
func resize[T](p: typed_ptr T, count: uint64) -> (typed_ptr T, string)
func resize[T](p: typed_ptr T, count: uint64, zero: bool) -> (typed_ptr T, string)
```

Resizes a block previously obtained from `new` to hold `count` values of `T`, preserving the lesser of the old and new sizes' worth of existing contents.

**The tail follows `new`'s default.** When the block grows, the newly added region beyond the preserved contents is zeroed unless `zero: false` is passed — same polarity as §11.1, same reasoning, and `zero: false` is the same claim (nothing in the tail is read before it is written). The preserved region is untouched either way; `zero` never re-zeroes contents `resize` just carried over.

The overflow rule from §11.1 applies to `count * sizeof(T)` here identically.

* **On success:** the returned pointer is valid and `p` must not be used again — treat this exactly like a transfer, even though it isn't compiler-enforced (ownership's `.transfer()` discipline doesn't reach `typed_ptr T`, so nothing catches a stale use). If the original block was obtained with an `align` argument (§11.1), the resized block is **not** guaranteed to preserve that alignment — `resize` carries no `align` parameter of its own, so a resized SIMD-style buffer must be re-checked (or re-allocated with `new[T](count, align: ...)` and copied) rather than assumed to still satisfy the original alignment.
* **On failure:** `p` is untouched and still valid; the returned pointer is `nil` and the string is non-empty. This is the one place a failure path leaves the *input* pointer alive rather than zeroed — the boundary-tuple's zero-value rule (foundation §35.5) applies to the *return*, not to `p`.

```vertex
var buf, err = new[uint8](64)
if err != "" { panic("alloc failed: " + err) }

let grown, err2 = resize(buf, 256)
if err2 != "" {
    // buf is still valid and still 64 bytes — free the old block, bail
    delete(buf)
    panic("resize failed: " + err2)
}
buf = grown   // buf now refers to the resized block; bytes 64..256 are zeroed
```

---

## 12. `copy` / `zero`

### 12.1 `copy` — Overlap-Safe, Always

```vertex
func copy[T](dst: typed_ptr T, src: typed_ptr T, n: uint64)
```

Copies `n` values of `T` from `src` to `dst`. Always overlap-safe (memmove semantics) — there is deliberately no separate overlap-unsafe variant. A split between an overlap-unsafe copy and an overlap-safe move would be a footgun, not a feature, so it collapses to one word here.

```vertex
copy(dst, src, 1024)
```

### 12.2 `zero` — Zero Existing Memory

```vertex
func zero[T](p: typed_ptr T, count: uint64)
```

Writes `count * sizeof(T)` zero bytes starting at `p`. Does not allocate or free; `p` must already point at a live block at least that large (from `new`, `&x`, or an array's backing storage). Cannot fail — there is no boundary tuple here, matching `copy` rather than `new`/`resize`.

This is distinct from `new`'s zeroing (§11.1), which is about the state a *fresh* allocation starts in. `zero` re-clears memory that is **already alive and has been written** — a reused scratch block between passes, a stack buffer, a region being scrubbed after it held a secret. Calling `zero` on a block that just came out of `new` with the default is redundant, and a lint may flag it.

```vertex
let buf, err = new[uint8](1024)   // already zeroed
if err != "" { panic("alloc failed: " + err) }
defer delete(buf)

fill(buf, 1024)
zero(buf, 1024)   // meaningful here — the block has been written since
```

**No overflow channel.** Unlike `new`/`resize` (§11.1), `copy` and `zero` return nothing, so there is no failure path for an overflowing or block-exceeding `n`/`count` to take: a size whose byte extent overflows `uint64`, or that runs past either block's extent, is undefined — the §3.1 rule, applied to bulk operations. The bounds are the caller's promise, same as every other operation in this file.

---

## 13. Null

`typed_ptr T` is the one type that accepts `nil` — the sole exception to foundation.md §35's "no general nil."

```vertex
var p: typed_ptr int32 = nil
if p == nil { }
```

`nil` participates in **equality only**: `p == nil` and `p != nil` are the entire surface. Ordering against `nil` (`p < nil`), arithmetic from `nil` (`nil.add(1)` — there is no receiver), and dereferencing `nil` are, respectively, a compile error, a compile error, and undefined behavior. `addr(p)` on a binding *holding* `nil` is fine — it addresses the slot, not the pointee.

This is also the zero value `new` and `resize` (§11) hand back on their failure path, matching the boundary-tuple convention's zero-value rule (foundation §35.5) applied to a pointer type.

**Not the same exception as `abstract`.** An `abstract` handle (interop §2) also has a zeroed representation, but that is a *different* mechanism: the zero value is legal only as an error-path value paired with a non-empty error string (the boundary tuple, interop §3), never a value compared against `nil`. `abstract` has no comparable `nil` state — absence is always the tuple, never a pointer-style null check. Don't treat the two zero-representations as interchangeable just because both types are "handle-shaped."

---

## 14. Illegal Forms

```vertex
&p.add(1)  // error: `.add` already computes the offset; `&` here would be
           //        dereferencing the result, not offsetting `&p` — write
           //        `&(p.add(1))` if a dereferenced read is what's meant

p.add(p2)  // error: `.add` takes a count (uint64), not another typed_ptr —
           //        pointer + pointer is undefined; only pointer.diff(pointer)
           //        exists (§4)

&x = 1     // error: `x` is not a typed_ptr — nothing to dereference-write

addr(x)    // error: `x` is not a typed_ptr — `&x` is already its address (§2.1)

addr(p.add(1))
           // error: `addr` requires an addressable binding or field path,
           //        not a computed temporary (§2.1)

p < nil    // error: `nil` participates in equality only (§13)

let d = p2.diff(q)
           // undefined — `p2` and `q` address unrelated blocks; `.diff`
           //             carries the same-block contract (§4). Not caught.

nsViewHandle as typed_ptr uint8
           // error: `NSView` is an object-graph handle (Objective-C) —
           //        abstract -> typed_ptr T requires a memory-flat
           //        classification (§8)

let h: WebSocket = raw as WebSocket
           // error: no typed_ptr T -> abstract cast exists —
           //        abstract handles are minted only at the
           //        foreign boundary (interop §4.2–§4.3)

let p = &x
delete(p)
           // undefined — `p` was never returned by new/resize;
           //             deleting a stack address is not a
           //             compile error, it is undefined behavior (§11.2)

let buf, err = new[uint8](16)
let p2 = buf.add(20)
&p2
           // undefined — 20 elements past a 16-element block; not caught,
           //             matches C pointer-arithmetic UB (§3.1). One-past-
           //             the-end (buf.add(16)) is legal to hold, just not
           //             to dereference.

let raw, err = new[uint8](16, zero: false)
let first = raw.at(0)
           // undefined — reading an unzeroed block before writing it.
           //             `zero: false` is a claim that every byte is
           //             written before it is read (§11.1); nothing
           //             checks the claim.

new[float32](16, align: 3)
           // undefined — `align` (3) is not a power of two (§11.1);
           //             treated as an allocation failure, not a
           //             separate diagnostic

func (w: var Widget) new() { }
           // error: `new` is a reserved builtin name, not a
           //        declarable member — same footing as `.transfer()`
           //        being reserved in ownership.md §6.8

func (p: typed_ptr int32) addr() { }
           // error: `addr` is a reserved builtin name (§2.1) —
           //        same footing as `new` above
```