# Vertex Lowering

Source construct → VIR. One section per construct, each ending in VIR.

`grammar.md` and `semantics.md` are normative for the source language; VIR
(`vir.md`) is normative for the target. This document is normative only for the
mapping between them. Where it contradicts a chapter file, this document wins
for lowering questions and the chapter is wrong.

---

## 0. The Contract

1. **Every cost is decided here.** If a construct's cost is not visible in this
   document, the front end mis-modelled it.
2. **No lowering introduces a runtime question.** No drop flags, no type tags,
   no dispatch tables, no unwinder. Anything requiring one is a front-end error
   instead — this is `semantics.md` §15 restated as a codegen obligation.
3. **VIR is CPU-only.** Device code (§19) and the `js`/`wasm` build tags (§21.5)
   never reach VIR.

### 0.1 Spelling assumptions

VIR's grammar fixes instruction *shape* but leaves three operand spellings
underspecified. This document writes them as:

| Written here | Meaning |
| --- | --- |
| `p = alloca.ptr N, align A` | frame slot of `N` bytes at alignment `A` |
| `q = index.ptr p, n` | `n` is a **byte** offset; the front end multiplies by `sizeof(T)` |
| `got = cmpxchg.iN p, exp, new, succ, fail` | yields the observed value; success is `got == exp` |

If VIR settles on different spellings, only these three lines change. See §21.8.

---

## 1. The VIR Surface Vertex Uses

| VIR feature | Used by |
| --- | --- |
| `iN`, `fN`, `ptr` | every scalar (§5) |
| `vec[T,N]` | `vector[T,N]` construction, arithmetic, comparison, `blend`/`min`/`max`/`clamp` (§12) |
| `struct`, `array[T,N]` | aggregates, in memory only |
| `alloca.ptr` | every `var` slot, every temporary aggregate |
| `field.ptr`, `index.ptr` | field and element addressing |
| `load`/`store`, `memcopy`/`memmove`/`memset` | copies and teardown |
| `switch` | `switch` statements, enum tags, async state dispatch |
| `br_if` + `trap` | bounds checks |
| `sdiv`/`udiv`/`srem`/`urem` | `/` and `%` — trap on zero for free (§15) |
| `stoint`/`utoint` | float→int, traps out of range for free (§15) |
| atomics + `fence` | `shared T` refcounts only (§10) |
| `call.<fnsig>` | closures, foreign vtables, device launches |
| `tailcall` | closure thunks (§13) |
| `noreturn` + `unreachable` | `panic` (§15) |
| `loc` | one per source statement |

Unused, and why:

| VIR feature | Why unused |
| --- | --- |
| `valist`, `va_start`/`va_arg`/`va_end` | Vertex cannot *define* a C-variadic function; it only calls them (§18.2) |
| `f16` | no source spelling |
| `i1` beyond comparisons | `bool` is `i8` (§5); a lane predicate's `vec[i1,N]` form is the sole other user, and it is a comparison result too, never a stored representation (§12.5) |

---

## 2. The Runtime Module — `builtins/rt`

VIR has no built-in heap (VIR §1), so allocation, threads, the reactor, and the
map table are **declared externs**, not opcodes. This is the complete list;
nothing else is assumed to exist.

Every Vertex module that needs one emits the corresponding `link`/`extern`
group. `rt` ships as a static library built from Vertex + VIR itself.

```vir
link static "vertexrt"

extern "vertexrt":
  fn rt_alloc(size i64, align i64) ptr
  fn rt_alloc_zeroed(size i64, align i64) ptr
  fn rt_realloc(p ptr, old i64, size i64, align i64) ptr
  fn rt_free(p ptr, size i64, align i64) void
  fn rt_panic(msg ptr, len i64) void noreturn
  fn rt_map_new(ksz i64, vsz i64, hash ptr, eq ptr, kdrop ptr, vdrop ptr) ptr
  fn rt_map_get(m ptr, k ptr) ptr
  fn rt_map_set(m ptr, k ptr, v ptr) void
  fn rt_map_erase(m ptr, k ptr) void
  fn rt_map_free(m ptr) void
  fn rt_chan_new(cap i64, esz i64, edrop ptr) ptr
  fn rt_chan_send(c ptr, v ptr) void
  fn rt_chan_recv(c ptr, out ptr) i32
  fn rt_chan_try(c ptr, out ptr) i32
  fn rt_chan_close(c ptr) void
  fn rt_chan_drop(c ptr) void
  fn rt_select(descs ptr, n i64, has_default i32) i64
  fn rt_thread_spawn(entry ptr, arg ptr) i64
  fn rt_task_spawn(frame ptr, resume ptr) ptr
  fn rt_task_await(c ptr, frame ptr) i32
  fn rt_reactor_run(root ptr, resume ptr) i32
  fn rt_readable(fd i32, frame ptr) i32
  fn rt_writable(fd i32, frame ptr) i32
  fn rt_cstr_new(p ptr, len i64) ptr
  fn rt_cstr_free(p ptr) void
end
```

**Sizes and alignments are passed to free.** Reason: a sized-deallocation ABI
lets `rt` use size-class bins without a per-block header. Rust's `dealloc` takes
the layout for the same reason; C's `free` cannot, and pays a header word for it.

**`rt_alloc` returns null on failure.** Allocation failure panics at the call
site, not inside `rt` — `memory.md` §11.1 hands a boundary tuple back for
explicit `new[T]`, and that path checks null itself.

**Refcounting is not in this list.** `shared T` retain/release lower to inline
VIR atomics (§10.2). Reason: they are 2–3 instructions with no bookkeeping;
Swift pays a call because ObjC side tables force it, and Vertex has no
equivalent. Rust's `Arc` is inline for the same reason.

---

## 3. Names and Symbols

### 3.1 Vertex → VIR identifiers

A VIR module is one Vertex **package**; `namespace` is the package path.

| Vertex | VIR ident |
| --- | --- |
| `func add` | `add` |
| `func (w: Widget) rename` | `Widget_rename` |
| `func (w: Widget) init` | `Widget_init`, named: `Widget_init_withRect` |
| `func (w: Widget) deinit` | `Widget_deinit` |
| instantiation `min[float64]` | `min__f64` |
| instantiation `Pair[int32, string]` | `Pair__i32_str` |

Type arguments encode as their VIR type name (`i32`, `f64`, `ptr`) or, for named
types, the type's own VIR ident. Nested instantiations recurse; VIR's flat
namespace requires the result be unique per module, which monomorphization
already guarantees.

### 3.2 Compiler-synthesized names

Reserved prefix **`_V`**. Synthesized helpers:

| Name | Purpose |
| --- | --- |
| `_Vcopy_T` | synthesized deep copy (§7.1) |
| `_Vdrop_T` | synthesized teardown (§7.3) |
| `_Vhash_T`, `_Veq_T` | `comparable` support for `map[K]V` (§11.3) |
| `_Vthunk_f` | non-capturing function used as a value (§13.2) |
| `_Vresume_f` | async state machine body (§16) |
| `_Vtramp_f` | thread entry trampoline (§17.1) |

This requires reserving the `_V` prefix in `semantics.md` §1.8 — see §21.1.

### 3.3 Export and mangling

`export` on a VIR `fn`/`global` for every package-level Vertex declaration.
VIR's own Itanium-style mangling (VIR §6.3) applies on top; nothing at the
Vertex level pre-mangles for the linker.

Monomorphized instances are **not** exported. Reason: VIR has no `linkonce` or
COMDAT, so two modules instantiating `min[int32]` would collide at link time.
Each module emits its own internal copy. Cost is duplication, matching Rust's
per-CGU instantiation; see §21.3 for the alternative.

`main` in package `main` emits `entry` (§16.4).

---

## 4. Bindings

| Source | Lowering |
| --- | --- |
| `let x = e` | a named VIR value; no slot |
| `var x = e` | a named VIR value **unless** a slot is forced |
| `var x: T` (no init) | zeroed slot or zeroed value |
| `_` | expression evaluated, result discarded |

A slot is forced when the binding is: passed to a `mut` parameter or receiver,
the operand of `addr` (`memory.md` §2.1), an aggregate (§5.3), captured by a
closure that outlives it, live across an `await` (§16.2), or an operand of `===`
(`foundation_spec.md` §12 defines class identity as the slot address).

Reason for demoting `foundation_spec.md` §2's "`var` is always a real stack
slot": the join convention (VIR §4.3) already carries a reassigned name across
blocks without memory, so the slot is only needed when an *address* is. This is
unobservable except through `===`, which is why `===` is on the list.

```vertex
var i = 0
while i < 5 { i += 1 }
```

```vir
  i = const.i32 0
  br loop
loop:
  c = slt.i32 i, 5
  br_if c, body, done
body:
  i = add.i32 i, 1
  br loop
done:
```

No slot, no phi — the loop-carried value is VIR §4.3 rule 4 verbatim.

---

## 5. Layout

### 5.1 Scalars

| Vertex | VIR |
| --- | --- |
| `int8`/`int16`/`int32`/`int64` | `i8`/`i16`/`i32`/`i64` |
| `uint8`…`uint64`, `byte` | same widths; signedness lives in the opcode |
| `int`/`uint` | `i32` or `i64` by target pointer width |
| `float32`/`float64` | `f32`/`f64` |
| `bool` | `i8`, values 0 and 1 |
| `char` | `i32` |
| `typed_ptr T`, `abstract`, `unique T`, `shared T`, `weak T` | `ptr` |
| unit enum | discriminant width |
| `vector[T, N]` | `vec[T, N]` — a register class, like the scalars above, not an aggregate (§12.1) |

`bool` is `i8`, not `i1`. Reason: `i1` has no memory representation the ABI
agrees on; comparisons yield `i1` and are widened at the store. `vec[T,N]`
faces no such problem: it is never stored to memory in a form the ABI must
agree on beyond ordinary element-wise byte layout, since VIR maps it directly
to a hardware vector register (§12.1).

### 5.2 Aggregates

| Vertex | VIR |
| --- | --- |
| `struct S` / `class S` | `struct S` — identical, no header, no vptr |
| `[N]T` | `array[T, N]` |
| tuple `(A, B)` | `struct` with generated ident |
| `string` | `struct _Vstr(ptr, i64)` |
| slice `[]T` view | `struct _Vslice(ptr, i64)` |
| `[]T` dynamic | `struct _Vvec(ptr, i64, i64)` — ptr, len, cap |
| `map[K]V` | `ptr` (one word, §11.3) |
| range `a..b` | `struct _Vrange_iN(iN, iN)` |
| `func` value | `struct _Vfn(ptr, ptr)` — code, env |
| payload enum | `struct` — tag + `array[i8, N]` (§9.4) |

Struct field order is declaration order with natural alignment (VIR §6.1);
Vertex adds no reordering. Reason: field order is observable through interop
`byval` and through `field.ptr` offsets a foreign header may assume.

`vector[T, N]` and the lane predicate are deliberately absent from this table:
they are register-class types (§5.1), not memory aggregates, and never appear
in it.

### 5.3 Aggregates are never values

VIR §3: aggregates are memory-only and never held in named values. Consequences,
all of them forced:

* Every aggregate parameter is `ptr` or `byval[S]`.
* Every aggregate return is `sret[S]` on a `void` function — including every
  boundary tuple (§8).
* Every aggregate temporary is an `alloca`.
* "Copying" an aggregate is `memcopy`, never an assignment.

**This rule does not apply to `vector[T, N]` or the lane predicate.** Both are
register-class types under VIR's own hardware mapping (VIR §1), exactly like
`iN`/`fN`/`ptr` — they are held in named values, passed by value, and returned
by value with no `sret`, no `byval`, and no `alloca` forced by their size
alone. See §12.

---

## 6. Calls — the Three Conventions

| Signature | VIR parameter | Caller emits |
| --- | --- | --- |
| `x: T` (shared) | thin → value; aggregate → `ptr` | nothing |
| `x: mut T` | `ptr` | address of the caller's slot |
| `x: var T` (owning) | thin → value; aggregate → `byval[S]` | transfer: nothing; copy: §7.1 first |

`vector[T, N]` and the lane predicate are thin (§12.6), so they follow the
first and third rows exactly like any scalar: a `vec[T,N]` parameter or return
is an ordinary VIR value, never a pointer, `byval`, or `sret`.

**Shared aggregates pass as a bare `ptr`.** VIR has no `noalias` or per-parameter
`readonly`, so the Law of Exclusivity is discharged entirely in the front end and
**is not transmitted to VIR**. The optimizer therefore cannot exploit it. See
§21.4 for the proposed VIR param attributes that would recover this.

**Owning aggregates use `byval[S]`.** VIR requires the caller's object stay live
and unmutated for the call — which is exactly true after a transfer, since the
source is dead (`semantics.md` §5.3.1). A large inline aggregate transfer is
therefore a `memcopy`; there is no header/payload split to exploit. Same as Rust,
where a move of a large `[u8; 4096]` is a memcpy the optimizer is expected to
elide.

Arguments evaluate left to right (`semantics.md` §15.1); VIR is sequential, so
emission order *is* evaluation order.

Named arguments resolve to positional order in the front end — no trace in VIR.

Variadics lower to a stack `array[T, N]` plus a `_Vslice` over it, `N` fixed at
each call site. No `valist` is involved.

```vertex
func rename(w: mut Widget, tag: string) { }
rename(w, "draft")
```

```vir
  wslot = alloca.ptr 4, align 4
  store.i32 wslot, w
  s = alloca.ptr 16, align 8
  lit = addr .Lstr0
  store.ptr s, lit
  lenp = field.ptr s, 1
  store.i64 lenp, 5
  call rename, wslot, s
```

---

## 7. Copy, Transfer, Teardown

### 7.1 Copy

A bare owning use is a copy. Classification:

| Type contains | Copy |
| --- | --- |
| only scalars, fixed arrays of scalars, slices, `typed_ptr`, `abstract`, unit enums, non-capturing `func`, `vector[T,N]`, the lane predicate | **trivial** — register move or `memcopy` |
| `string`, `[]T`, `map`, capturing closure, `unique T` | **deep** — `_Vcopy_T` |
| `shared T`, `weak T` | **retain** — atomic increment |
| a class with `deinit`, or a field of any of the above | deep |

Deep copies emit one `_Vcopy_T` per type, called at the copy site, not inlined.
Reason: code size. A bare copy is already the documented-expensive path
(`ownership_spec.md` §10); duplicating its body at every site multiplies that.
C++ generates one copy constructor for the same reason.

`_Vcopy_T` signature: `fn _Vcopy_T(dst ptr sret[T], src ptr) void`.

### 7.2 Transfer

`.` — emits nothing. A transfer is the ordinary by-value pass or store, made
legal by liveness. Its entire lowering is the *absence* of a `_Vdrop_T` call at
the source's original end of liveness.

### 7.3 Teardown

`_Vdrop_T(p ptr)` per non-trivial type. Body: fields in **reverse declaration
order** (`semantics.md` §15.2), preceded by the user `deinit` if the type is a
class that declares one.

Emission points, in order at each scope exit:

1. `defer` bodies, reverse registration order
2. locals, reverse declaration order

Both are emitted before **every** terminator that leaves the scope — `br` on
fall-through, `return`, and the `br` of `break`/`continue`. With no unwinder the
edge set is finite and static (`semantics.md` §15.3).

`defer` is block-scoped, so registration is static: there is no runtime defer
list and no mask. The implementation is duplication of the deferred call onto
each exit edge, and nothing else.

A transferred binding is simply omitted from step 2. No flag is set and none is
read — this is the whole reason conditional transfer is a compile error.

```vertex
func f() {
    var a = Frame()
    defer log("bye")
    if c { return }
    g(var a)
}
```

```vir
  a = alloca.ptr 32, align 8
  call Frame_init, a
  br_if c, early, cont
early:
  call log, .Lstr_bye
  call _Vdrop_Frame, a
  return
cont:
  call g, a                  ; transfer — no drop emitted for `a`
  call log, .Lstr_bye
  return
```

---

## 8. The Boundary Tuple

`(T, string)` is `struct` with generated ident, returned by `sret`. Always —
`(int32, string)` included.

```vertex
func parseInt(s: string) -> (int32, string)
let n, err = parseInt(s)
```

```vir
struct _Vt_i32_str(i32, ptr, i64)

export fn parseInt(out ptr sret[_Vt_i32_str], s ptr) void:
  ...
end

  t = alloca.ptr 24, align 8
  call parseInt, t, s
  n = load.i32 t
  ep = field.ptr t, 1
  err_p = load.ptr ep
  lp = field.ptr t, 2
  err_len = load.i64 lp
```

Failure costs exactly what success costs: the same stores into the same slot.

A backend may promote the `sret` slot to a register pair for a non-`export`
function, since the slot is a local `alloca` with no address escaping. This is a
codegen optimization, not a VIR-level guarantee. `foundation_spec.md` §9's claim
that small tuples return "in register pairs" is wrong as a VIR statement and
right as a machine-code statement.

---

## 9. Control Flow

### 9.1 Loops

Every loop lowers to a `while` shape (`foundation_spec.md` §13), then to blocks.

| Source | Iteration state |
| --- | --- |
| `for i in a..b` | one counter |
| `for x in arr` | counter + `index.ptr` |
| `for i, x in arr` | counter + `index.ptr` |
| `for mut x in arr` | counter; body writes through `index.ptr` |
| `for var x in arr` | counter; element moved out, `_Vdrop` of the container header after the loop, no per-element drop |
| `for c in s` | byte cursor + UTF-8 decode |
| `for b in s.bytes()` | byte cursor |
| `for k, v in m` | `rt` iterator handle |

### 9.2 `if` / `&&` / `||`

`br_if`. Short-circuit is a branch, not a select — it is the only dynamic
property these operators have (`semantics.md` §6.1.4). A lane predicate is
never an operand here: it cannot reach `&&`/`||`/`if` at the source level
(`semantics.md` §10.5.1), so no such branch is ever emitted for one.

### 9.3 `switch`

Dense integer or enum-tag cases → VIR `switch`. Sparse → compare chain.
String cases → length compare then `memcopy`-free byte compare via `rt`-free
inline loop. `fallthrough` → `br` to the next case block. A `switch` over an
enum with no `default` is exhaustive by §9.9 of `semantics.md`, so no default
edge is emitted; the verifier's required default label targets a block ending in
`unreachable`.

### 9.4 Enums

Unit enum: the discriminant integer. `as intN` is a no-op reinterpretation.

Payload enum: `struct E(tag iN, payload array[i8, N])` where `N` is the largest
variant's size and the struct's alignment is the largest variant's alignment.
Case bindings are `field.ptr` + cast into the payload — views, not copies.

Copy and drop of a payload enum switch on the tag and recurse into the live
variant only.

```vertex
switch s {
case .Point:
case .Circle(r):
}
```

```vir
  tag = load.i8 s
  switch tag, unreach, 0 case_point, 1 case_circle
case_circle:
  pl = field.ptr s, 1
  r = load.f32 pl
  ...
```

---

## 10. Heap

### 10.1 `unique T`

One allocation, one pointer word, no header.

| Operation | Lowering |
| --- | --- |
| `unique(e)` | `rt_alloc(sizeof(T), alignof(T))`, then move `e` in |
| transfer | move the word |
| bare copy | `rt_alloc` + `_Vcopy_T` on the pointee |
| teardown | `_Vdrop_T(p)` then `rt_free(p, sizeof(T), alignof(T))` |

No header is why there is no `unique → weak` path: nothing exists to observe.

### 10.2 `shared T`

Per-`T` control block:

```vir
struct _Vsh_Widget(i64, i64, struct Widget)   ; strong, weak, payload
```

| Operation | VIR |
| --- | --- |
| `shared(e)` | `rt_alloc`, store `strong=1`, `weak=1`, move payload |
| retain (handle copy) | `atomic_add.i64 p, 1, relaxed` |
| release | `atomic_sub.i64 p, 1, acqrel`; if old was 1 → drop payload, then release weak |
| `weak(a)` | `atomic_add.i64 wp, 1, relaxed` |
| weak release | `atomic_sub.i64 wp, 1, acqrel`; if old was 1 → `rt_free` |
| `upgrade(w)` | increment-if-nonzero loop |

Relaxed retain, acq-rel release: the standard Arc ordering. Reason: retain only
needs the count to be atomic; release must synchronize with every prior release
so the destructor sees all writes. The `weak` count starts at 1 and is owned
collectively by the strong count — the "one weak for all strongs" trick, so
strong-zero decrements weak exactly once.

```vir
  ; upgrade(w) -> (shared T, string)
retry:
  cur = atomic_load.i64 p, relaxed
  z = eq.i64 cur, 0
  br_if z, dead, try
try:
  nx = add.i64 cur, 1
  got = cmpxchg.i64 p, cur, nx, acquire, relaxed
  ok = eq.i64 got, cur
  br_if ok, live, retry
```

`deinit` reaching its owner only through `upgrade` (`semantics.md` §5.6.6) is
what makes this sound: a direct back-edge would be a strong count already at
zero.

---

## 11. Containers

### 11.1 `string`

`{ptr, len}` over UTF-8, no NUL. Literals are a `global` byte array plus a
constant length; `addr .Lstr0` is the pointer.

**A bare copy of a `string` genuinely duplicates the bytes.** Reason: the
alternative is a refcount header, which puts atomics on a type whose spelling
contains no `shared`. That breaks rule 0.1 — cost must be visible in the source.
`foundation_spec.md` §5's "may be shared or interned" license is therefore
**unused**; it can be reinstated later only behind a header, and only if the
atomics are acceptable. Swift accepts them; Vertex, having no ObjC bridge to pay
for, should not.

Literal-backed strings copy their bytes like any other. A copy of a string never
allocates when the destination is a parameter and the source outlives the call —
but that is a front-end optimization on top of the shared convention, not a
representation change.

### 11.2 `[]T`

`{ptr, len, cap}`. Growth is amortized doubling through `rt_realloc`.
`push` may reallocate, which is why interior pointers do not exist and slices
are lifetime-checked instead.

Index → bounds check → `index.ptr`:

```vir
  len = load.i64 lenp
  ok = ult.i64 i, len
  br_if ok, inbounds, oob
oob:
  trap
inbounds:
  off = mul.i64 i, 4
  ep = index.ptr base, off
  v = load.i32 ep
```

A constant index provably out of range is a compile error, so no check is
emitted for it (`semantics.md` §6.3.2).

### 11.3 `map[K]V`

One `ptr` to an `rt` table. The table is type-erased; the front end supplies
`sizeof(K)`, `sizeof(V)`, and four function pointers: `_Vhash_K`, `_Veq_K`,
`_Vdrop_K`, `_Vdrop_V` (null when trivial).

Reason for type erasure here and monomorphization everywhere else: a hash table
is ~2 KB of code with no per-type specialization payoff beyond the comparison,
which is already passed as a pointer. Go and Swift both erase their map cores.

`m[k] = nil` lowers to `rt_map_erase`. This is the one place `nil` appears
outside `typed_ptr`.

### 11.4 Slice views

`{ptr, len}`, borrowed, never deep-copied, never dropped. The Law of
Exclusivity forbids mutating or transferring the viewed buffer while the view is
live — enforced entirely in the front end, invisible in VIR (§21.4). A slice
view that is the destination of a vector store (§12.3) carries a `mut` borrow
rather than the ordinary shared borrow this section otherwise describes
(`semantics.md` §5.4.5); the distinction is front-end bookkeeping only and
leaves no separate trace here beyond the store itself.

---

## 12. Vectors

`vector[T, N]` (grammar.md §4, semantics.md §10) lowers directly to VIR's
native `vec[T, N]` register class (VIR README §3, §1) — unlike every other
Vertex aggregate, it is **not** memory-only (§5.3's rule does not apply to it):
VIR maps it straight to a hardware register class, exactly like `iN`/`fN`/`ptr`.

### 12.1 Type and tier

| Vertex | VIR |
| --- | --- |
| `vector[T, N]` | `vec[T, N]` |
| lane predicate | `vec[i1, N]` |

Legality is gated by the target's feature tier (VIR README §7.1): `vec[T, N]`
is legal only if `N` fits the selected tier's native width for `T`. Where the
selected tier is narrower than the source `N` — `vector[float32, 8]` targeting
an SSE-only tier — the front end splits it into `ceil(N / W)` operations over
`vec[T, W]`, `W` the tier's native lane count, before VIR ever sees the wider
form. Every construction, arithmetic, and comparison opcode below is then
emitted once per split piece. VIR's own rule that `N` fits the tier holds
unchanged; the split is entirely a front-end obligation, matching
semantics.md §10.1 note and proposed_vector.md §10.1.

On a tier with `W = 1` (no SIMD support at all), every vector operation lowers
to `N` scalar instructions of the corresponding non-`vec` opcode — the same
code shape a hand-written scalar loop would produce, and its cost is exactly
what the source's `N` promised.

### 12.2 Construction

| Source (semantics.md §10.4) | VIR |
| --- | --- |
| splat, constant argument | `const.vec[T,N]` (VIR README §6.2), or a `global` plus `load.vec[T,N]` |
| splat, runtime argument | `splat.vec[T,N] v` — no such opcode exists yet; see §21.11 |
| load, `VectorType(buf, i)` | bounds compare + `br_if` → `trap` (shape identical to §11.2's array bounds check, computed over `i + N` against the source's length), then `index.ptr` + `load.vec[T,N] p, align E`, `E` being `T`'s own element alignment — never `vec[T,N]`'s natural alignment, which is what makes the load unaligned per semantics.md §10.4.2 |
| lane conversion | the ordinary destination-explicit conversion opcode (VIR §4.1) with a `vec[T,N]` destination; a float→int lane conversion traps per-lane exactly as its scalar counterpart traps out of range |

A constant index provably out of range on a fixed array, used as the load's
index, is a compile-time error (semantics.md §10.4.2) and emits no runtime
check, exactly as for an ordinary constant array index (§11.2).

### 12.3 Store

`copy(view, vec_value)` (semantics.md §10.4, final paragraph) lowers to
`index.ptr` + `store.vec[T,N] p, v, align E` — `E` again the element
alignment, never the vector's. This bypasses the `memcopy`/`memmove` path (§7)
entirely: a vector store is a single instruction, not a byte-wise bulk
operation.

### 12.4 Operations

| Source (semantics.md §10.5, §6.1) | VIR |
| --- | --- |
| `+ - * &+ &- &* & \| ^ ~ << >>` | the identical opcode used for the scalar case (VIR §4.1), operands and result typed `vec[T,N]` |
| `== != < <= > >=` | the identical comparison opcode, yielding `vec[i1, N]` in place of `i1` — this is VIR's own stated behavior ("Comparisons: Yield `i1` or `vec[i1, N]`", VIR §4.1), not an extension this document adds |
| `min`/`max` | `min.fN`/`max.fN` for float `T`, or `smin`/`smax`/`umin`/`umax` for integer `T` (signed or unsigned per `T`) — each already legal on `vec[T,N]` operands under VIR's arithmetic rules |
| `clamp(v, lo, hi)` | `max` then `min`, both vector forms above, matching a scalar clamp's usual two-instruction lowering |
| `blend(m, a, b)` | `select.vec[T,N] m, a, b` — no such opcode exists yet; see §21.11 |
| `v[k]`, constant `k` | `extract.vec[T,N] v, k` — no such opcode exists yet; see §21.11 |

Integer `/` and `%` on a vector are rejected in the front end (semantics.md
§6.1.2) and never reach this table — there is no lowering for them because
there is no legal source construct to lower.

### 12.5 The lane predicate is never in memory

A `vec[i1, N]` value lives only in a register binding — the join convention
(VIR §4.3) covers it exactly as it covers any other named value. It is never
the target of `field.ptr`/`index.ptr`, never a `global` or `const` initializer,
and never a `struct` member, matching semantics.md §10.5's rule that it cannot
be named in a signature, field, or channel element type. The backend's choice
of representation — a dedicated mask register on a target that has one, an
all-ones/all-zeros `vec[iN,N]` on one that doesn't — is exactly the kind of
target-dependent codegen VIR's strict-semantics principle explicitly permits
under a fixed, opcode-defined meaning (VIR README §1), and this document takes
no position on which a given backend picks.

### 12.6 Ownership and cost

A `vec[T,N]` or `vec[i1,N]` value is thin (semantics.md §10.8): passed and
returned exactly as any scalar is (§6, "thin → value" row), copied by register
move, and torn down by nothing — no `_Vdrop_T` is ever generated for one, and a
struct containing a vector field is not thereby made non-trivial (§7.1's
classification table).

### 12.7 Foreign boundary and device code

Vectors are rejected in the front end before reaching a `declare` boundary
(semantics.md §10.3.2) and before reaching a `gpu` or `npu` body or signature
(semantics.md §10.3.1, §11.1, §11.2) — the restriction is fully discharged
before lowering begins, for the same reason `js` and `wasm` never reach VIR at
all (§21.5): nothing in §18 or §19 needs to special-case vectors, because a
vector can never arrive there.

---

## 13. Closures

### 13.1 Representation

`struct _Vfn(ptr, ptr)` — code, env. `code` always has the environment as its
first parameter.

Capturing closures allocate `env` with `rt_alloc` at creation and own it: the
closure's `_Vdrop` drops each captured value then frees `env`. Captures are
copied in by value at creation.

Reason for heap `env`: `func makeAdder(n: int32) -> func(int32) -> int32`
(`foundation.md` §31) lets a closure outlive its frame. Escape analysis may
demote a non-escaping `env` to an `alloca`; that is an optimization, not a
representation.

Assigning to a capture is a compile error, so `env` is written once and never
mutated after creation — which lets the backend treat it as immutable.

### 13.2 Non-capturing functions as values

A non-capturing function used as a `func` value gets `_Vthunk_f(env ptr, ...)`,
which ignores `env` and `tailcall`s the real function. The `_Vfn` pair is
`{addr _Vthunk_f, null}`.

Reason: the alternative is a null-`env` check at every indirect call. Go emits
the same wrapper for the same reason.

### 13.3 At the foreign boundary

Only a non-capturing function crosses (§12.6 of `semantics.md`). The value
passed is `addr f` — the *real* function, not the pair and not the thunk. The
front end knows statically that it is non-capturing, so there is nothing to
strip at runtime.

---

## 14. Generics

Monomorphization, one VIR `fn` per instantiation (§3.1 for naming), internal
linkage (§3.3).

* A generic never instantiated emits nothing.
* A method-constraint call lowers to a direct `call` on the concrete type. No
  vtable, no dictionary, no `fnsig` indirection.
* Copy/drop cost is the concrete type's; a generic body cannot see which, which
  is exactly why the cost lint fires per instantiation.
* Recursive instantiation is bounded by the front end's depth limit before
  lowering ever runs.

---

## 15. Traps, Panic, Undefined Behavior

Three of Vertex's runtime checks are free — VIR already traps:

| Vertex | VIR |
| --- | --- |
| division or remainder by runtime zero | `sdiv`/`udiv`/`srem`/`urem` trap |
| `int64.MIN / -1` | `sdiv` traps |
| float→int out of range, incl. NaN/±Inf | `stoint`/`utoint` trap |

Emitted explicitly:

| Vertex | VIR |
| --- | --- |
| array/slice index out of range | compare + `br_if` → `trap` |
| `panic(msg)` | `call rt_panic, p, len` then `unreachable` |

`panic` satisfying "every path returns" (`semantics.md` §13.3) is exactly VIR's
`noreturn` + `unreachable` requirement (VIR §4.2), so the two rules discharge
each other.

**Arithmetic wrapping.** `+`, `-`, `*` lower to VIR `add`/`sub`/`mul`, which wrap
modulo 2^N with no UB. `&+`, `&-`, `&*` lower to **the same instructions**. The
operators are distinguishable only in constant expressions, where plain overflow
is a compile error and the wrapping forms are not. See §21.7.

**`typed_ptr` UB.** Out-of-bounds `.add`, cross-block `.diff`, stale `delete`,
reading an unzeroed block — all lower to plain `index.ptr`/`load`/`rt_free` with
no check, landing in VIR UB categories 1, 2, and 8. Nothing in this document
narrows them; that is the whole tradeoff of reaching for `typed_ptr`.

---

## 16. Async

### 16.1 Shape

An `async` function becomes:

1. `struct _Vframe_f(state i32, <locals live across a suspend>, <child frames>, result)`
2. `fn _Vresume_f(frame ptr) i32` — one block per resume point, dispatched by
   `switch` on `state` at entry
3. A stub `fn f(...)` that initializes the frame

Return code from `_Vresume_f`: `0` = complete, `1` = suspended.

The join convention makes this cheap: state lives in the frame in memory, so
there is nothing for phi nodes to have merged and no register allocation to
reconstruct across a suspend.

### 16.2 `await`

Split the block. Store live locals into the frame, set `state`, return `1`. The
resume block reloads.

Only values live *across* the suspend go in the frame — which is where
`async.md` §7.1's memory-footprint claim actually comes from.

### 16.3 Child frames

`await g()` where `g` is `async` embeds `_Vframe_g` **inside** `_Vframe_f`. One
allocation covers a whole await chain.

**Consequence: recursive `async` is a compile error.** The frame size would not
be computable. Rust hits the same wall and answers with `Box::pin`; Vertex has no
boxed-future type and should not grow one — spawn instead, which allocates a
fresh frame (§16.5). This is a new front-end rule (§21.6).

### 16.4 `main`

`main` is the reactor root. It lowers as an async function whose frame is an
`alloca` in `entry`:

```vir
export fn main() i32 entry:
  fr = alloca.ptr 128, align 8
  store.i32 fr, 0
  rc = call rt_reactor_run, fr, addr _Vresume_main
  return rc
end
```

### 16.5 `async f()` — spawn

Heap-allocate the frame, hand it and `_Vresume_f` to `rt_task_spawn`, which
returns a `chan T`. Awaiting that channel is an ordinary channel receive (§17.3).

### 16.6 `async.Readable` / `Writable`

`rt_readable(fd, frame)` returns immediately-ready or suspends. These two are
the entire reactor seam; a custom reactor reimplements them and nothing else.

---

## 17. Threads, Channels, `select`

### 17.1 `thread f(x)`

1. `alloca` an argument pack, move arguments in
2. `rt_chan_new(1, sizeof(T), _Vdrop_T)`
3. `rt_thread_spawn(addr _Vtramp_f, pack)`

`_Vtramp_f(arg ptr) void` unpacks, calls `f`, sends the result, closes the
channel, frees the pack.

### 17.2 Channels

One `ptr` to an `rt` channel. Type-erased core, element size and an element drop
function supplied at construction.

The drop function is what makes ownership sound across the channel: `send` is an
owning position, so the value is moved into the buffer and the *receiver*
inherits teardown; values still buffered at `rt_chan_drop` are dropped by the
channel using that pointer.

`chan[shared T]` is rejected in the front end because channel element types need
a zero value (`semantics.md` §12.1.3), which is also why `rt_chan_try` can write
a zeroed slot on failure without knowing `T`. A `chan[vector[T,N]]` is legal by
the same rule, since a vector has a zero value (semantics.md §10.2); a channel
of the lane predicate is not legal, since the predicate cannot be named as a
channel element type at all (semantics.md §10.5.2).

### 17.3 `.receive()`

| Context | Lowering |
| --- | --- |
| bare | `rt_chan_recv` — blocks the OS thread |
| `await ch.receive()` | `rt_task_await(ch, frame)` — suspension point, split per §16.2 |

The two are distinguished by the `await` in the source, never by the channel.

### 17.4 `select`

An `alloca`'d array of `{chan ptr, i32 op}` descriptors, then `rt_select`, which
returns the ready index; a `switch` dispatches to the case body.

Bare and awaited `select` are two different runtime entry points (blocking vs.
reactor-registered). The no-mixing rule (`channels.md` §4.3) is what makes the
choice static — with mixing there would be no single primitive to wait on.

---

## 18. Interop

The `declare` block's build tag and variant tag pick the call shape. In every
case, the abstract handle is a `ptr` and no foreign layout is described.

### 18.1 Flat C (`linux`, `windows`, non-framework `darwin`)

Direct `extern` group, direct `call`. `mut T` scalar out-params are already
pointers (§6), so `mut int32` *is* `int32*` with no adaptation.

### 18.2 Foreign variadics

Declared with `...` in the VIR `fnsig`; VIR handles varargs at the call site.
Vertex never emits `va_start`/`va_arg`/`va_end` because it cannot define a
C-variadic function.

### 18.3 Strings at the boundary

Vertex strings have no NUL. Each `string` argument marshals:

```vir
  cs = call rt_cstr_new, sp, slen
  call SDL_CreateWindow, cs, ...
  call rt_cstr_free, cs
```

The free is emitted on every exit edge of the call's statement, like a `defer`.

Reason for a runtime call rather than a dynamically-sized `alloca`: VIR's
`alloca` is a fixed frame slot, and a dynamic one would need a VIR extension for
a case that is already at a foreign boundary paying a call. See §21.8.

### 18.4 Objective-C (`declare framework`, `darwin`)

`objc_msgSend` with a cached selector. Selectors cannot be `global` initializers
(VIR §6.2 forbids calls in initializers), so each is a lazily-filled `global`:

```vir
global sel_center ptr = null

  s = atomic_load.ptr sel_center, relaxed
  n = eq.ptr s, null
  br_if n, reg, send
reg:
  s = call sel_registerName, .Lsel_center
  atomic_store.ptr sel_center, s, relaxed
  br send
send:
  call objc_msgSend, recv, s
```

The race is benign — `sel_registerName` is idempotent and returns the same
pointer — so relaxed ordering is correct and no lock is needed.

### 18.5 C++ (`cxx`, Itanium; `windows` raw vtable; `com`)

Non-virtual member calls use the mangled symbol in the `extern` group, `this`
first. Virtual and COM calls load the vptr at offset 0, index it, and
`call.<fnsig>`.

**Exceptions cannot be caught.** VIR has no unwinder and Vertex has no `catch`.
A C++ exception escaping into Vertex is undefined behavior, and every foreign
declaration is effectively `nounwind` by fiat. The `"no-exceptions"` variant tag
is therefore not a tuning knob but the only configuration with defined behavior
across the boundary, and §4.2's exceptions-on default should be reconsidered
(§21.9).

### 18.6 `abstract` → `typed_ptr T`

Memory-flat imports: a no-op reinterpretation, since the handle already *is* an
address. Object-graph imports (JS, Darwin frameworks): rejected in the front end;
nothing reaches lowering.

---

## 19. Device Code

**Neither `gpu` nor `npu` bodies reach VIR.** VIR is CPU-only by charter.

| Marker | Body compiles to | Embedded as |
| --- | --- | --- |
| `gpu` | PTX / AMDTX / MSL IR | `global` byte blob |
| `npu` | StableHLO | `global` byte blob |

The launch site lowers to an argument pack plus a device-runtime call:

```vir
  pack = alloca.ptr 24, align 8
  ...store args...
  call rt_gpu_launch, addr .Lblob_matmul, .Lname_matmul, 16, 256, pack, 24, out
```

`npu` is the same shape with no block/thread arguments — the shape is carried by
the tensor types, which exist only inside the body and its own signature.

`rt_gpu_launch` and `rt_npu_execute` join §2's extern list for any module that
contains a launch. Both are synchronous: the call returns a plain host-typed
result, matching `accel.md` §1.3 and §2.3.

Everything restricted about an `npu` body — scalar selectors, no `break`, no
subscripting, loop-carried shape invariance — is checked before this point and
is a property of the StableHLO emitter, not of VIR.

---

## 20. Tests

A `build test` file compiles to its own module with an `entry`.

| Form | Lowering |
| --- | --- |
| `test -> Expected(T, "...")` | exported `fn`; runner compares emitted formatting to the literal |
| `test` with no expectation | exported `fn`; the test passes if it returns |
| `test -> Expected(error)` | **not lowered** — a compile-time assertion; a body that compiles is a test failure |
| `test -> Expected(error, "...")` | not lowered; additionally matches the diagnostic |

`Expected(error)` never producing code is why `diagnostics.md` is a real
dependency: the assertion is on diagnostic text, which lives nowhere in this
pipeline.

---

## 21. What This Document Forces

Each item is a change or a ratification needed elsewhere. Nothing here is
optional; the lowering above assumes all of it.

### 21.1 Reserve the `_V` prefix — `semantics.md` §1.8
Synthesized symbols (§3.2) need a namespace user code cannot enter. Add: an
identifier beginning `_V` may not be declared. One line, no other consequence.

### 21.2 `foundation_spec.md` §9 is wrong on tuple returns
VIR aggregates are never values, so all multi-value returns are `sret` (§8).
Register-pair returns are a backend promotion, not a VIR guarantee. Fix the
sentence when §3.2 of `todo.md` folds that file into this one.

### 21.3 Monomorphized instances duplicate across modules
No `linkonce`/COMDAT in VIR (§3.3). Accept the duplication, or add a
`linkonce` fn-attr to VIR. **Recommend accepting** — dedup is a size
optimization and VIR's flat-namespace guarantee is worth more.

### 21.4 Exclusivity is not transmitted to VIR
Shared parameters, `mut` parameters, and slice borrows all pass as bare `ptr`
(§6, §11.4). The front end proves non-aliasing and then discards the proof.
**Proposal:** add `noalias` and `readonly` as *param* attributes to VIR §2.3's
`param-attr`. This is the single highest-value VIR change on this list — it is
the whole reason to have an exclusivity law and a backend in the same project.

### 21.5 `js` and `wasm` cannot lower to VIR
VIR §7.1 admits real silicon only and explicitly excludes bytecode and VM
targets. Those two build tags need a separate backend. **Recommend** a parallel
`wasm-lowering.md` rather than widening VIR's arch table, which would contradict
its stated principle. This document is native-only until that exists.

### 21.6 Recursive `async` must be a compile error
Child frames embed (§16.3), so a recursive async function has no computable
frame size. New front-end rule; the error message should point at spawning.

### 21.7 `&+`/`&-`/`&*` lower identically to `+`/`-`/`*`
Runtime arithmetic already wraps (`semantics.md` §3.2), so the overflow
operators differ only in constant expressions. Either accept them as
documentation, or make plain runtime overflow trap and give the operators real
work. **Recommend the second** — an operator that generates no distinct code is
a spelling, and "wrap silently by default" is the choice Rust reversed in
release mode for good reasons. This is a language decision, not a lowering one,
but lowering is where it becomes visible.

### 21.8 Three VIR spellings need pinning
`alloca` operand form, `index.ptr` scaling, and `cmpxchg`'s result shape (§0.1).
Also: whether `alloca` can be dynamically sized, which would remove the
`rt_cstr_new` round trip in §18.3.

### 21.9 Reconsider `exceptions on` as the C++ default
An escaping C++ exception is UB (§18.5) and there is no unwinder to make it
otherwise. The current default in `abstract_interfaces_spec.md` §4.2 advertises a
capability that does not exist. **Recommend** defaulting to no-exceptions and
requiring an explicit tag to link against an exceptions-on library.

### 21.10 Ratifying `todo.md` §2 — what lowering needs

| Open decision | Lowering's answer |
| --- | --- |
| §2.1 partial moves | **Keep the conservative rule.** Per-field liveness needs per-field drop flags, which contradicts §0.2 and every table in §7.3. Relaxing this is not a checker change, it is a codegen model change. |
| §2.2 subscript overlap | Lowering-neutral — the check is entirely front-end and emits nothing either way. Decide on ergonomics. |
| §2.3 `deinit` on structs | Lowering-neutral. `_Vdrop_T` is generated by the same rule for both kinds; only the trivial/non-trivial classification (§7.1) would shift. Decide on language grounds. |
| §2.4 channel zero values | **Confirmed necessary.** `rt_chan_try` writes a zeroed slot on failure without knowing `T` (§17.2). |

### 21.11 Vector construction, extraction, and blend need opcodes VIR doesn't yet name
VIR already gives `vec[T,N]` a full arithmetic, comparison, and min/max story
(§12.4), because those reuse the identical opcodes the scalar case uses.
Three operations have no scalar analog to reuse and are missing from the VIR
surface entirely:

* **`splat.vec[T,N] v`** — broadcast a runtime scalar into every lane (§12.2).
  The constant case is already covered by `const.vec[T,N]`; only the
  runtime-argument form is missing.
* **`extract.vec[T,N] v, k`** — read lane `k` as a `T`, `k` a compile-time
  immediate (§12.4). Every mainstream target has a single instruction for
  this; VIR currently has no opcode to reach it.
* **`select.vec[T,N] m, a, b`** — per-lane select keyed by a `vec[i1,N]` mask
  (§12.4), the `blend` builtin's entire lowering. This is distinct from
  `min`/`max`/`clamp` in that it is not expressible as existing arithmetic
  opcodes composed together — real hardware ships a dedicated blend/select
  instruction (`vblendvps` and equivalents) for exactly this shape, and
  synthesizing it from bitwise `and`/`or`/`not` on mismatched-width operands
  would require exactly the kind of implicit narrowing conversion
  `semantics.md` §10.7 was written to avoid.

All three are minimal, single-instruction-shaped additions consistent with
VIR's existing `vec[T,N]` support elsewhere; none introduces a new register
class, a new memory form, or a runtime question. **Recommend adding all three**
before `vector` construction can actually be lowered end to end — without
them, §12.2 and §12.4 name opcodes that do not exist.