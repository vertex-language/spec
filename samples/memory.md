## Memory (`typed_ptr` & Pointer Arithmetic)

---

## 0. No Import

`typed_ptr` and every primitive over it are core grammar, the same tier as
`sizeof`, `alignof`, `reinterpret`, and `&`. No package, no namespace prefix.

`new`, `delete`, `resize`, `copy`, `zero`, and `addr` are reserved builtin names
(grammar.md, *Reserved builtin names*). The `func` lines in this file describe
call shapes; they are not declarations you can write, shadow, or attach to a
receiver.

`panic` is likewise reserved. It appears in the failure paths below because an
allocation failure is often not recoverable at the call site; it takes a
`string` and does not return.

**When to reach for this document at all.** `[]T`, `map[K]V`, and `chan T` cover
the cases where a container owns its storage discipline and can afford to abort
on exhaustion. `typed_ptr` is what those types are built *from*: a container
author writing a fallible `try_reserve`, an arena with a fallback pool, an
embedded allocator that must not abort, a buffer a foreign call fills in place.
Outside that audience, reaching for `typed_ptr` gives up every guarantee in
`ownership.md` and buys nothing.

---

## 1. The Pointer Type

```vertex
var p: typed_ptr int32
```

`typed_ptr T` is the raw, last-resort pointer: one machine word holding an
address. No ownership tracking, no refcount, no compiler discipline. Nothing in
`ownership.md` governs it, and nothing in this file takes a `var` parameter or is
written with the transfer marker.

* A bare copy (`let q = p`) is a register move.
* A marked transfer (`let q = var p`) is legal and identical in cost — it marks
  `p` dead, but there is no payload to distinguish.
* No teardown is ever emitted when a `typed_ptr` binding goes dead. The pointee's
  lifetime is yours, via `delete` (§11.2).

Two copies are two unchecked aliases. This is the one type where the exclusivity
rules (ownership §9) are convention rather than proof: the compiler will not
notice that `p` and `q` reach the same block, and will not stop you passing both
into a call that writes through one of them.

`typed_ptr T` is a `TypeLit`, so it composes wherever a type is admissible — a
field, a local, a parameter, an element type. What it may not be is the direct
base of another `PointerType`; see §2.1.

---

## 2. `&` — Address-of / Dereference

Direction comes from the operand's written type: `&` on an ordinary value takes
its address, `&` on a `typed_ptr T` dereferences it.

```vertex
var x: int32 = 42
let p = &x          // address-of  — int32 -> typed_ptr int32
let v = &p          // dereference — typed_ptr int32 -> int32
&p = 99             // dereference on the write side
```

The write form derives without a special rule: an `AssignTarget` is a
`PrimaryExpr`, and `&p` is one (grammar, *Assignment*).

This is the only symbolic operation on `typed_ptr` beyond comparison (§5): its
contract never varies (read or write through a live, aligned, initialized `T`),
so a method name would disambiguate nothing. Everything that *computes a new
address* is a method — §3, §6.

`&` binds tighter than `.`, which is the one precedence fact worth memorizing
here:

```vertex
&p.add(1)           // parses as (&p).add(1)  — almost never what you meant
&(p.add(1))         // dereferenced read at offset 1
```

**Generic bodies.** Where `x`'s type is a type parameter `T`, `&x` is always
address-of, at every instantiation, including `T = typed_ptr U`. The rule keys on
the statically written type, and a bare `T` is not spelled `typed_ptr`. A generic
that must dereference takes `typed_ptr U` explicitly. A source line never flips
meaning per instantiation.

### 2.1 `addr` — Address of a Pointer

`&p` already means dereference, leaving the address *of* a `typed_ptr` binding
unspellable. `addr` fills that hole and nothing else.

```vertex
func addr[T](p: typed_ptr T) -> typed_ptr (typed_ptr T)
```

```vertex
var p: typed_ptr int32 = nil
let pp = addr(p)              // points at the slot holding p
&pp = someOther               // writes a new address into p
```

* Requires an addressable operand — a `var` binding or field path, the same rule
  as a `mut` argument (ownership §2).
* Exists only for `typed_ptr` operands; `addr(x)` on anything else is a compile
  error with a fix-it pointing at `&`.
* This is the honest spelling for a foreign `T**` out-param the boundary tuple
  doesn't absorb (abstract_interfaces §2).

Nesting composes (`addr(pp)` is `typed_ptr (typed_ptr (typed_ptr T))`); each `&`
peels one level. The parentheses are required — a `PointerType` may not be the
direct base of another (grammar, *Channel and pointer types*).

---

## 3. Arithmetic — Methods, Scaled by `sizeof(T)`

Computing an address is the operation whose bounds contract is easiest to get
wrong, so it is a named method: the name is where the reader's eye catches it and
where a doc comment can carry §3.1. There is no operator form — `+`, `-`, `+=` do
not exist on `typed_ptr T`, and there is no `++`/`--` anywhere in the language.

```vertex
func (p: typed_ptr T) add(n: int64) -> typed_ptr T
func (p: typed_ptr T) sub(n: int64) -> typed_ptr T
```

```vertex
let p2 = p.add(1)
let p3 = p.sub(4)
p = p.add(1)
```

The count is in elements, not bytes: `p.add(1)` moves `sizeof(T)` bytes. This is
the entire reason the pointer carries a `T` at all.

### 3.1 Bounds Are Computed, Not Checked

`.add`/`.sub` compute an address; they do not check one. The address one element
past the last valid one is legal to *hold* (end-of-range loops), not to
dereference. Anything further out, or any dereference of an out-of-bounds
pointer, is undefined (§14.2). The compiler proves nothing about `typed_ptr`
bounds — that is the tradeoff of reaching for it over `[]T`, whose subscript is
bounds-checked and panics (foundation §22.4).

---

## 4. Pointer − Pointer

```vertex
func (p: typed_ptr T) diff(q: typed_ptr T) -> int64
```

```vertex
let n: int64 = p2.diff(p)
```

Yields the signed element count (not bytes) from `p` to `p2`. Defined only when
both pointers address the same allocated block — from one `new`/`resize`, one
`&x`, or one array's backing storage — with either permitted to sit
one-past-the-end. Unrelated blocks are undefined (§14.2).

There is no subtraction operator form, for §3's reason.

---

## 5. Comparison — Stays Symbolic

Comparing addresses never dereferences, so there is nothing to flag.

```vertex
p == p2    p != p2    p < p2    p <= p2    p > p2    p >= p2
```

Equality is defined for any two `typed_ptr T` of the same `T`, including against
`nil` (§13). Ordering carries §4's same-block contract, and ordering against
`nil` is a compile error — `nil` participates in equality only.

`===` and `!==` are identity operators on classes (foundation §14) and do not
apply to a `typed_ptr`; `==` already compares addresses.

---

## 6. Indexing — Methods, Not Sugar

Indexing is arithmetic plus dereference, so it follows §3, not §2.

```vertex
func (p: typed_ptr T) at(n: int64) -> T
func (p: typed_ptr T) setAt(n: int64, value: T)
```

```vertex
let x = p.at(3)       // read  — equivalent to &(p.add(3))
p.setAt(3, 9)         // write — equivalent to &(p.add(3)) = 9
```

`p[3]` is not a form. Bracket subscripting belongs to `[]T`, `[N]T`, and
`map[K]V`, all of which are checked; giving the unchecked type the checked type's
spelling is exactly the confusion this design avoids.

---

## 7. Casting — `as`

```vertex
let raw:  typed_ptr uint8  = p as typed_ptr uint8    // reinterpret
let addr: uint64           = p as uint64             // pointer -> integer
let back: typed_ptr int32  = addr as typed_ptr int32 // integer -> pointer
let auto: typed_ptr uint8  = p                       // target known — `as` inferred
```

`as` is a static reinterpretation of the address's type, never a read or write, so
it stays symbolic like §5. `typed_ptr T as typed_ptr U` is legal for any `T`, `U`
— the compiler is not checking that the bytes at that address mean a `U`.

**The last line is a scoped exception, not a general one.** Foundation §6 admits
no implicit numeric conversions: every width or signedness change is written. The
inferred form here is available only where both sides are pointer types and the
target is fixed by an annotation, an argument, or a return position. A pointer
carries no width and no signedness, so there is no information to lose and
nothing for the reader to reconstruct. `p as uint64` and `addr as typed_ptr int32`
cross between a pointer and an integer and are never inferred.

---

## 8. Casting a Foreign Handle — `abstract` → `typed_ptr T`

An `abstract` handle (abstract_interfaces §1) is a distinct type: no arithmetic,
no dereference, no stride. The cast is legal in one direction only, decided by the
declaring block's ABI linkage (abstract_interfaces §0):

| Linkage | Handle is | `as typed_ptr T` |
| --- | --- | --- |
| C / C++ / COM (`linux`, `windows`, `darwin`), `wasm` | an address into linear memory | legal — ordinary reinterpretation |
| Objective-C (`declare framework` on `darwin`), JS (`build js`) | a runtime object reference | error — no byte representation |

```vertex
let raw: typed_ptr uint8 = sdlWindowHandle as typed_ptr uint8   // memory-flat: ok
let bad: typed_ptr uint8 = nsViewHandle as typed_ptr uint8      // object-graph: error
```

There is no return path. Minting an `abstract` handle is the foreign library's job
(abstract_interfaces §3.2–§3.3), never a client-side reinterpretation. Each
`abstract` alias stays nominally distinct — one memory-flat handle casting cleanly
says nothing about another.

---

## 9. `reinterpret()` — When the Target Can't Be Inferred

`reinterpret(T, p)` is `p as typed_ptr T` written where §7's inferred form has
nothing to infer from — an argument to an untyped position, an element of a
literal, a subexpression. It is one of the three call forms that take a `Type` in
argument position (grammar, *Type-operator and constructor calls*).

```vertex
let bytes = reinterpret(uint8, p)
let back  = reinterpret(Widget, bytes)
```

The two spellings mean the same thing and neither reads or writes memory. Prefer
`as` where the target type is already written down; `reinterpret` exists so that
the alternative to it is not an intermediate binding introduced solely to hang an
annotation on.

---

## 10. `sizeof` / `alignof`

```vertex
sizeof(Type)  -> uint64
alignof(Type) -> uint64
```

```vertex
let s  = sizeof(int32)     // 4
let a  = alignof(int32)    // 4
let s2 = sizeof(Widget)
```

Both take a `Type`, not an expression — `sizeof(x)` on a binding is an error.
Both yield `uint64`, which is the width `new`, `resize`, `copy`, and `zero` all
take, so a size computation composes with an allocation without a cast:

```vertex
let buf, err = new[uint8](sizeof(Header) * 4)
```

`sizeof(T)` on a class is the size of the object, and a class is byte-for-byte
identical in layout to a struct (foundation §27).

---

## 11. Allocation — `new` / `delete` / `resize`

`new` and `resize` are fallible calls under the boundary-tuple convention
(foundation §35).

> **Why these report and `[]T` doesn't.** `[]T` and `chan T` panic on exhaustion
> (channels.md §1) because they own their storage discipline. `new` is the
> primitive those types are built *from* — a container author writing a fallible
> `try_reserve`, an arena with a fallback pool, or an embedded allocator that must
> not abort needs the failure as a value. That audience is the entire reason
> `typed_ptr` exists.

### 11.1 `new[T]` — Allocate

```vertex
func new[T](count: uint64) -> (typed_ptr T, string)
func new[T](count: uint64, align: uint64) -> (typed_ptr T, string)
func new[T](count: uint64, zeroed: bool) -> (typed_ptr T, string)
func new[T](count: uint64, align: uint64, zeroed: bool) -> (typed_ptr T, string)
```

Allocates `count * sizeof(T)` bytes. On success the string is `""`; on failure the
pointer is `nil` (§13) and the string carries a message such as `"out of memory"`.

**Zeroed by default.** `zeroed: false` opts out and returns memory whose contents
are unspecified.

```vertex
let buf, err = new[uint8](1024)              // zeroed — the default
if err != "" {
    panic("allocation failed: " + err)
}
defer delete(buf)

buf.setAt(0, 0xFF)
```

This is a deliberate exception to ownership §11's cost-transparency rule, on that
rule's own reasoning: when both mistakes are silent, the default goes to the safe
one. Forgetting `zeroed: false` costs a memset the optimizer can often elide, and
which the OS has already paid for any allocation large enough to come from fresh
pages. Forgetting `zeroed: true` under the old polarity cost a garbage read —
which is how the previous tenant's bytes escape.

**`zeroed: false`** is for blocks provably written before read: a container's
growth path, a buffer a foreign call fills, scratch under a length discipline. It
is a claim, not a hint — reading before writing is undefined (§14.2), and nothing
checks it.

```vertex
// Vector.grow — push() only writes below `length`, so the fresh tail
// is never readable before it is written.
let raw, err = new[T](newCapacity, zeroed: false)
```

**`align`** guarantees the block starts on an `align`-byte boundary rather than
`alignof(T)`. It must be a power of two: a literal that isn't is a compile error, a
computed one that isn't panics. This is a bug in the source, not a state of the
machine, so it does not take the failure channel.

```vertex
let simdBuf, err = new[float32](16, align: 32, zeroed: false)
```

**Overflow.** A `count` whose byte size overflows `uint64` *is* an allocation
failure (`nil`, non-empty string) — `count` is routinely caller data read off a
wire or a file header, exactly the thing a container author must reject rather
than die on.

**Inference.** `T` may be explicit or inferred from the binding it flows into:

```vertex
var buf: typed_ptr uint8
var err: string
buf, err = new(1024)   // T inferred as uint8
```

This is a **stated exception to generics §5.3**, which says a type parameter
appearing only in the return type cannot be inferred and must be supplied. `T`
appears nowhere in `new`'s value parameters, so the general rule would reject the
line above. The exception is scoped to `new` and `resize`, and only where the
destination's pointer type is already written down — the same shape, and the same
reasoning, as §7's inferred pointer cast. Every other generic call obeys
generics §5.3 unchanged.

> **Why `zeroed:` and not `zero:`.** `zero` is a reserved builtin name (§12.2),
> and a reserved name may not be a parameter label.

### 11.2 `delete` — Release

```vertex
func delete[T](p: typed_ptr T)
```

Releases a block from `new` or a successful `resize`; `T` is inferred from `p`
under the ordinary rule (generics §5.2), since it appears in a value parameter.
`delete(nil)` is a no-op. Deleting anything else is undefined (§14.2).

```vertex
delete(buf)
```

`delete` does not take the transfer marker and does not kill the binding: `p`
still holds its old address afterward, and nothing stops you dereferencing it.
Pair every allocation with a `defer delete(...)` at the point of allocation where
the block's lifetime is the scope's, and accept that anything else is a manual
argument you are making.

### 11.3 `resize[T]` — Resize

```vertex
func resize[T](p: typed_ptr T, count: uint64) -> (typed_ptr T, string)
func resize[T](p: typed_ptr T, count: uint64, zeroed: bool) -> (typed_ptr T, string)
```

Resizes a block from `new`, preserving the lesser of the old and new sizes'
contents. A grown tail follows §11.1's polarity: zeroed unless `zeroed: false`,
same claim, same lack of checking. The preserved region is untouched either way.
§11.1's overflow rule applies identically — note `resize` has no `align`
parameter, so a resized block is **not** guaranteed to keep an alignment the
original was allocated with.

* **Success:** the returned pointer is valid and `p` must not be used again. Read
  that as a transfer of the block, but only as a reading — `resize` takes a shared
  `typed_ptr`, the `var` marker plays no part, and nothing catches a stale use of
  `p`.
* **Failure:** `p` is untouched and still valid; the return is `nil` plus a
  message. This is the one place a failure path leaves the *input* alive —
  foundation §35.5's zero-value rule applies to the return, not to `p`.

```vertex
let grown, err2 = resize(buf, 256)
if err2 != "" {
    delete(buf)                  // still valid, still 64 bytes
    panic("resize failed: " + err2)
}
buf = grown
```

The reassignment on the last line is the whole discipline: one live name per
block. Keeping `buf` and `grown` both in scope is how a stale pointer survives
long enough to be dereferenced.

---

## 12. `copy` / `zero`

Neither allocates, frees, or fails. Bounds are the caller's promise; a size that
overflows or runs past either block's extent is undefined (§14.2).

Both operate on `typed_ptr T` only. Moving between a `[]T` and a block is done by
element or through the slice's own operations — these two primitives have no slice
form (see §15).

### 12.1 `copy`

```vertex
func copy[T](dst: typed_ptr T, src: typed_ptr T, n: uint64)
```

Copies `n` values of `T`, always overlap-safe (memmove semantics). There is
deliberately no overlap-unsafe variant — that split is a footgun, not a feature.

Both pointers are the same `T`. Copying between differently typed blocks means
saying so, with a cast at the call:

```vertex
copy(dst, src as typed_ptr uint8, n)
```

### 12.2 `zero`

```vertex
func zero[T](p: typed_ptr T, count: uint64)
```

Writes `count * sizeof(T)` zero bytes; `p` must already point at a live block that
large. Distinct from `new`'s zeroing (§11.1), which is about the state a *fresh*
block starts in — `zero` re-clears memory already alive and written: a reused
scratch block, a stack buffer, a region scrubbed after holding a secret. Calling
it on a default `new` block is redundant and a lint may flag it.

```vertex
fill(buf, 1024)
zero(buf, 1024)   // meaningful — the block has been written since
```

---

## 13. Null

`typed_ptr T` is the one type accepting `nil` — the sole exception to
foundation §35's "no general nil," and the zero value `new`/`resize` return on
failure. It is also the zero value of a `typed_ptr` type parameter in a generic
body (generics §6).

```vertex
var p: typed_ptr int32 = nil
if p == nil { }
```

`nil` participates in **equality only**. Ordering against it is a compile error,
`nil.add(1)` is a compile error (no receiver), and dereferencing it is undefined.
`addr(p)` on a binding holding `nil` is fine — it addresses the slot, not the
pointee.

**Not the same exception as `abstract`.** An `abstract` handle also has a zeroed
representation, but it is legal only as an error-path value paired with a
non-empty string (abstract_interfaces §2) and is never compared against `nil`.
Don't treat the two as interchangeable because both types are handle-shaped.

---

## 14. Appendix: Rejected and Undefined Forms

### 14.1 Syntax errors

These do not parse, or parse into a form the grammar has no reading for:

```vertex
func (p: typed_ptr int32) info() { }
               // a `ReceiverType` is a `TypeName`; a `PointerType` may not
               // be a receiver at all. There are no methods on typed_ptr T
               // beyond §3, §4, and §6.

var pp: typed_ptr typed_ptr int32
               // a PointerType may not be the direct base of another —
               // write typed_ptr (typed_ptr int32) (§2.1)
```

### 14.2 Compile errors

These parse and are rejected:

```vertex
&p.add(1)      // `&` binds tighter than `.` — this is (&p).add(1).
               // Write &(p.add(1)) for a dereferenced read.
p.add(p2)      // `.add` takes a count; only p.diff(p) exists (§4)
p + 1          // no operator arithmetic on typed_ptr (§3)
&x = 1         // `x` is not a typed_ptr — nothing to dereference-write
addr(x)        // `x` is not a typed_ptr — `&x` is already its address (§2.1)
addr(p.add(1)) // `addr` needs an addressable binding or field path (§2.1)
p < nil        // `nil` participates in equality only (§13)
sizeof(x)      // `sizeof` takes a Type, not an expression (§10)

nsViewHandle as typed_ptr uint8
               // object-graph handle — no byte representation (§8)
let h: WebSocket = raw as WebSocket
               // no typed_ptr -> abstract cast exists (§8)
new[float32](16, align: 3)
               // literal `align` is not a power of two (§11.1)

func (w: var Widget) new() { }    // reserved builtin name
func (w: Widget) addr() { }       // reserved builtin name
```

### 14.3 Undefined behavior — none of this is caught

| Form | Rule |
| --- | --- |
| Forming an address more than one past a block's end | §3.1 |
| Dereferencing out of bounds (`&`, `.at`, `.setAt`, `copy`, `zero`) | §3.1 |
| `.diff` or ordering across unrelated blocks | §4, §5 |
| Reading an unzeroed block before writing it | §11.1 |
| `delete` of `&x`, of an already-deleted pointer, or of an offset pointer | §11.2 |
| Using `p` after a successful `resize` | §11.3 |
| `copy`/`zero` past either block's extent | §12 |
| Dereferencing `nil` | §13 |

```vertex
let buf, err = new[uint8](16)
&buf.add(20)       // 20 past a 16-element block. buf.add(16) is legal to
                   // hold, just not to dereference.

let p = &x
delete(p)          // never came from new/resize
```