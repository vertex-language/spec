# Vertex Language Grammar

## Grammar — Memory (`typed_ptr`)

---

## 0. Import

```vertex
import "builtins/memory"
```

---

## 1. The Pointer Type

```vertex
var p: typed_ptr int32
```

---

## 2. Address-of / Dereference — both spelled `&`

Direction is inferred from the operand's type: `&` on an ordinary value takes its address; `&` on a `typed_ptr T` dereferences it.

```vertex
var x: int32 = 42
let p = &x          // address-of  — int32 -> typed_ptr int32
let v = &p          // dereference — typed_ptr int32 -> int32
&p = 99             // dereference on the write side — writes through p
```

---

## 3. Arithmetic (scaled by `sizeof(T)`)

```vertex
let p2 = p + 1
let p3 = p - 4
p += 1
p -= 1
p++
p--
```

---

## 4. Pointer − Pointer

```vertex
let n: int64 = p2 - p
```

---

## 5. Comparison

```vertex
p == p2
p != p2
p <  p2
p <= p2
p >  p2
p >= p2
```

---

## 6. Indexing — sugar for `&(p + i)`

```vertex
let x = p[3]
p[3]  = 9
```

---

## 7. Casting — `as`

```vertex
let raw:  typed_ptr uint8 = p as typed_ptr uint8   // reinterpret
let addr: uint64           = p as uint64            // pointer -> integer
let back: typed_ptr int32  = addr as typed_ptr int32 // integer -> pointer
let auto: typed_ptr uint8  = p                       // target known — `as` inferred
```

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

## 11. `memory.Copy` / `memory.Move`

```vertex
memory.Copy(dst, src, n)   // n bytes, dst/src must not overlap
memory.Move(dst, src, n)   // n bytes, overlap-safe
```

---

## 12. Raw Heap Allocation — `memory.Alloc` / `memory.Free` / `memory.Realloc`

`typed_ptr T` has no ownership tracking (§7/§8 of `ownership.md` never governs it — it is explicitly the last-resort raw pointer). Consequently the heap functions below are ordinary fallible calls under the boundary-tuple convention (foundation §35), not owning positions: nothing here is a `var` parameter, nothing accepts `.transfer()`, and the compiler enforces none of the discipline described below — it is manual, exactly like the pointer arithmetic in §3.

### 12.1 `memory.Alloc[T]` — Allocate, Uninitialized

```vertex
func memory.Alloc[T](count: uint64) -> (typed_ptr T, string)
```

Allocates space for `count` contiguous values of `T` (`count * sizeof(T)` bytes) and returns a pointer to it. Contents are **not** zeroed. Follows the standard fallibility convention: on success the string is `""`; on failure the pointer is `nil` (§13's zero value for `typed_ptr T`) and the string carries a message such as `"out of memory"`.

```vertex
let buf, err = memory.Alloc[uint8](1024)
if err != "" {
    panic("allocation failed: " + err)
}
defer memory.Free(buf)

buf[0] = 0xFF
```

### 12.2 `memory.Free` — Release

```vertex
func memory.Free[T](p: typed_ptr T)
```

Releases a block previously returned by `memory.Alloc`, `memory.AllocAligned`, or a successful `memory.Realloc`. `T` is inferred from `p`. `memory.Free(nil)` is a no-op. Freeing anything else — a pointer derived from `&x` (§2), a pointer already freed, or one offset from its original address (§3) — is undefined, the same way it is in the machine model this language lowers to (foundation_spec.md §1).

```vertex
memory.Free(buf)
```

### 12.3 `memory.Realloc[T]` — Resize

```vertex
func memory.Realloc[T](p: typed_ptr T, count: uint64) -> (typed_ptr T, string)
```

Resizes a block previously obtained from `memory.Alloc`/`memory.AllocAligned` to hold `count` values of `T`, preserving the lesser of the old and new sizes' worth of existing contents. Matches the pointer's underlying reallocation semantics:

* **On success:** the returned pointer is valid and `p` must not be used again — treat this exactly like a transfer, even though it isn't compiler-enforced (§7's discipline doesn't reach `typed_ptr T`, so nothing catches a stale use).
* **On failure:** `p` is untouched and still valid; the returned pointer is `nil` and the string is non-empty. This is the one place a failure path leaves the *input* pointer alive rather than zeroed — the boundary-tuple's zero-value rule (foundation §35.5) applies to the *return*, not to `p`.

```vertex
var buf, err = memory.Alloc[uint8](64)
if err != "" { panic("alloc failed: " + err) }

let grown, err2 = memory.Realloc(buf, 256)
if err2 != "" {
    // buf is still valid and still 64 bytes — free the old block, bail
    memory.Free(buf)
    panic("realloc failed: " + err2)
}
buf = grown   // buf now refers to the resized block
```

### 12.4 `memory.AllocAligned[T]` — Allocation With an Explicit Alignment

```vertex
func memory.AllocAligned[T](count: uint64, align: uint64) -> (typed_ptr T, string)
```

Same contract as §12.1, with the backing block guaranteed to start on an `align`-byte boundary rather than whatever `alignof(T)` (§10) would naturally give it — for SIMD buffers, DMA targets, or a foreign ABI that demands a specific alignment. `align` must be a power of two; violating that is an error on the same footing as an allocation failure (`nil`, non-empty string), not a separate error shape. Free with the same `memory.Free` as any other block — no `FreeAligned` counterpart exists, since alignment isn't recorded in the pointer.

```vertex
let simdBuf, err = memory.AllocAligned[float32](16, 32)   // 32-byte aligned
if err != "" { panic("aligned alloc failed: " + err) }
defer memory.Free(simdBuf)
```

### 12.5 `memory.Zero` — Zero Existing Memory

```vertex
func memory.Zero[T](p: typed_ptr T, count: uint64)
```

Writes `count * sizeof(T)` zero bytes starting at `p`. Does not allocate or free; `p` must already point at a live block at least that large (from `memory.Alloc`, `memory.AllocAligned`, `&x`, or an array's backing storage). Cannot fail — there is no boundary tuple here, matching `memory.Copy`/`memory.Move` (§11) rather than the allocation functions above.

```vertex
let buf, err = memory.Alloc[uint8](1024)
if err != "" { panic("alloc failed: " + err) }
defer memory.Free(buf)

memory.Zero(buf, 1024)   // equivalent to a zeroed Alloc, spelled explicitly
```

---

## 13. Null

`typed_ptr T` is the one type that accepts `nil` — the sole exception to foundation.md §35's "no general nil."

```vertex
var p: typed_ptr int32 = nil
if p == nil { }
```

This is also the zero value `memory.Alloc`, `memory.Realloc`, and `memory.AllocAligned` (§12) hand back on their failure path, matching the boundary-tuple convention's zero-value rule (foundation §35.5) applied to a pointer type.

**Not the same exception as `abstract`.** An `abstract` handle (interop §2) also has a zeroed representation, but that is a *different* mechanism: the zero value is legal only as an error-path value paired with a non-empty error string (the boundary tuple, interop §3), never a value compared against `nil`. `abstract` has no comparable `nil` state — absence is always the tuple, never a pointer-style null check. Don't treat the two zero-representations as interchangeable just because both types are "handle-shaped."

---

## 14. Illegal Forms

```vertex
&p + 1     // error: `&p` already dereferenced — nothing left to offset
p + p2     // error: pointer + pointer undefined — only pointer - pointer
&x = 1     // error: `x` is not a typed_ptr — nothing to dereference-write

nsViewHandle as typed_ptr uint8
           // error: `NSView` is an object-graph handle (Objective-C) —
           //        abstract -> typed_ptr T requires a memory-flat
           //        classification (§8)

let h: WebSocket = raw as WebSocket
           // error: no typed_ptr T -> abstract cast exists —
           //        abstract handles are minted only at the
           //        foreign boundary (interop §4.2–§4.3)

let p = &x
memory.Free(p)
           // undefined — `p` was never returned by Alloc/AllocAligned/
           //             Realloc; freeing a stack address is not a
           //             compile error, it is undefined behavior (§12.2)

memory.AllocAligned[float32](16, 3)
           // undefined — `align` (3) is not a power of two (§12.4);
           //             treated as an allocation failure, not a
           //             separate diagnostic
```