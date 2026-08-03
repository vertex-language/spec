# Vertex Lowering

Source construct → VIR. One section per construct, each ending in VIR.

`grammar.md` and `semantics.md` are normative for the source language; VIR
(`vir.md`) is normative for the target. This document is normative only for the
mapping between them, and wins over any chapter file on lowering questions.

---

## 0. The Contract

1. **Every cost is decided here.** A construct whose cost is invisible in this
   document was mis-modelled by the front end.
2. **No lowering introduces a runtime question.** No drop flags, no type tags,
   no dispatch tables, no unwinder. Anything requiring one is a front-end error
   (`semantics.md` §15 as a codegen obligation).
3. **VIR is CPU-only.** `gpu`/`npu` bodies (§19) and the `js`/`wasm` build tags
   (§21.5) never reach VIR.

### 0.1 Spelling assumptions

VIR fixes instruction shape but leaves three operand spellings underspecified.
This document writes them as:

| Written here | Meaning |
| --- | --- |
| `p = alloca.ptr N, align A` | frame slot of `N` bytes at alignment `A` |
| `q = index.ptr p, n` | `n` is a **byte** offset; the front end scales by `sizeof(T)` |
| `got = cmpxchg.iN p, exp, new, succ, fail` | yields the observed value; success is `got == exp` |

If VIR settles on different spellings, only these three lines change (§21.8).

---

## 1. The VIR Surface Vertex Uses

| VIR feature | Used by |
| --- | --- |
| `iN`, `fN`, `ptr` | every scalar (§5) |
| `vec[T,N]` | `vector[T,N]` construction, arithmetic, comparison, `blend`/`min`/`max`/`clamp` (§12) |
| `struct`, `array[T,N]` | aggregates, in memory only |
| `alloca.ptr` | every forced slot, every temporary aggregate |
| `field.ptr`, `index.ptr` | field and element addressing |
| `load`/`store`, `memcopy`/`memmove`/`memset` | copies and teardown |
| `switch` | `switch` statements, enum tags, async state dispatch |
| `br_if` + `trap` | bounds checks |
| `sdiv`/`udiv`/`srem`/`urem` | `/` and `%` — trap on zero for free (§15) |
| `stoint`/`utoint` | float→int, traps out of range for free (§15) |
| atomics + `fence` | `shared T` refcounts only (§10) |
| `call.<fnsig>` | closures, foreign vtables |
| `tailcall` | closure thunks (§13) |
| `noreturn` + `unreachable` | `panic` (§15) |
| `loc` | one per source statement |

Unused: `valist` and `va_*` (Vertex calls C-variadics but cannot define one,
§18.2); `f16` (no source spelling); `i1` outside comparison results (`bool` is
`i8`, §5; the lane predicate's `vec[i1,N]` is also comparison-only, §12.5).

---

## 2. The Runtime Module — `builtins/rt`

VIR has no built-in heap, so allocation, threads, the reactor, and the map table
are declared externs. This is the complete list. `rt` ships as a static library
built from Vertex + VIR.

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

* **Free takes size and alignment.** A sized-deallocation ABI lets `rt` use
  size-class bins with no per-block header.
* **`rt_alloc` returns null on failure.** The call site panics or, for explicit
  `new[T]` (`memory.md` §11.1), checks null and returns a boundary tuple.
* **Refcounting is not in this list.** `shared T` retain/release are inline VIR
  atomics (§10.2) — 2–3 instructions with no bookkeeping.

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
| `min[float64]` | `min__f64` |
| `Pair[int32, string]` | `Pair__i32_str` |

Type arguments encode as their VIR type name (`i32`, `f64`, `ptr`) or a named
type's own ident. Nested instantiations recurse; uniqueness per module is
guaranteed by monomorphization.

### 3.2 Compiler-synthesized names

Reserved prefix **`_V`** (§21.1).

| Name | Purpose |
| --- | --- |
| `_Vcopy_T` | synthesized deep copy (§7.1) |
| `_Vdrop_T` | synthesized teardown (§7.3) |
| `_Vhash_T`, `_Veq_T` | `comparable` support for `map[K]V` (§11.3) |
| `_Vthunk_f` | non-capturing function used as a value (§13.2) |
| `_Vresume_f` | async state machine body (§16) |
| `_Vtramp_f` | thread entry trampoline (§17.1) |

### 3.3 Export and mangling

`export` on a VIR `fn`/`global` for every package-level Vertex declaration.
VIR's Itanium-style mangling applies on top; nothing pre-mangles.

Monomorphized instances are **not** exported — VIR has no `linkonce`/COMDAT, so
two modules instantiating `min[int32]` would collide. Each module emits its own
internal copy (§21.3).

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
the operand of `addr`, an aggregate (§5.3), captured by a closure that outlives
it, live across an `await` (§16.2), or an operand of `===` (class identity is
the slot address).

The join convention carries a reassigned name across blocks without memory, so a
slot is needed only when an *address* is. This is unobservable except through
`===`, which is why `===` is on the list.

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
| `vector[T, N]` | `vec[T, N]` — a register class, not an aggregate (§12.1) |

`bool` is `i8` because `i1` has no ABI-agreed memory representation;
comparisons yield `i1` and widen at the store. `vec[T,N]` has no such problem —
it maps to a hardware vector register and is never stored in a form the ABI must
agree on beyond element-wise byte layout.

### 5.2 Aggregates

| Vertex | VIR |
| --- | --- |
| `struct S` / `class S` | `struct S` — identical, no header, no vptr |
| `[N]T` | `array[T, N]` |
| tuple `(A, B)` | `struct` with generated ident |
| `string` | `struct _Vstr(ptr, i64)` |
| slice `[]T` view | `struct _Vslice(ptr, i64)` |
| `[]T` dynamic | `struct _Vvec(ptr, i64, i64)` — ptr, len, cap |
| `map[K]V` | `ptr` (§11.3) |
| range `a..b` | `struct _Vrange_iN(iN, iN)` |
| `func` value | `struct _Vfn(ptr, ptr)` — code, env |
| payload enum | `struct` — tag + `array[i8, N]` (§9.4) |

Field order is declaration order with natural alignment; Vertex adds no
reordering, since order is observable through interop `byval` and through
`field.ptr` offsets a foreign header may assume.

`vector[T, N]` and the lane predicate are absent from this table: they are
register-class types (§5.1), never memory aggregates.

### 5.3 Aggregates are never values

VIR aggregates are memory-only. Forced consequences:

* Every aggregate parameter is `ptr` or `byval[S]`.
* Every aggregate return is `sret[S]` on a `void` function — boundary tuples
  included (§8).
* Every aggregate temporary is an `alloca`.
* "Copying" an aggregate is `memcopy`, never an assignment.

**This does not apply to `vector[T, N]` or the lane predicate** — both are
register-class types held in named values, passed and returned by value, with no
`sret`, `byval`, or size-forced `alloca` (§12).

---

## 6. Calls — the Three Conventions

| Signature | VIR parameter | Caller emits |
| --- | --- | --- |
| `x: T` (shared) | thin → value; aggregate → `ptr` | nothing |
| `x: mut T` | `ptr` | address of the caller's slot |
| `x: var T` (owning) | thin → value; aggregate → `byval[S]` | transfer: nothing; copy: §7.1 first |

`vector[T, N]` and the lane predicate are thin (§12.6) and follow the first and
third rows exactly like any scalar.

**Shared aggregates pass as a bare `ptr`.** VIR has no `noalias` or
per-parameter `readonly`, so the Law of Exclusivity is discharged in the front
end and is not transmitted to VIR; the optimizer cannot exploit it (§21.4).

**Owning aggregates use `byval[S]`.** VIR requires the caller's object stay live
and unmutated for the call, which is exactly true after a transfer. A large
inline aggregate transfer is therefore a `memcopy`.

Arguments evaluate left to right; VIR is sequential, so emission order *is*
evaluation order. Named arguments resolve to positional order in the front end.
Variadics lower to a stack `array[T, N]` plus a `_Vslice` over it, `N` fixed per
call site — no `valist`.

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

A bare owning use is a copy:

| Type contains | Copy |
| --- | --- |
| only scalars, fixed arrays of scalars, slices, `typed_ptr`, `abstract`, unit enums, non-capturing `func`, `vector[T,N]`, lane predicate | **trivial** — register move or `memcopy` |
| `string`, `[]T`, `map`, capturing closure, `unique T` | **deep** — `_Vcopy_T` |
| `shared T`, `weak T` | **retain** — atomic increment |
| a class with `deinit`, or a field of any of the above | deep |

One `_Vcopy_T` per type, called at the copy site, never inlined — a bare copy is
already the documented-expensive path; duplicating its body multiplies that.

`_Vcopy_T` signature: `fn _Vcopy_T(dst ptr sret[T], src ptr) void`.

### 7.2 Transfer

Emits nothing. A transfer is the ordinary by-value pass or store, made legal by
liveness; its entire lowering is the *absence* of a `_Vdrop_T` call at the
source's original end of liveness.

### 7.3 Teardown

`_Vdrop_T(p ptr)` per non-trivial type. Body: fields in reverse declaration
order, preceded by the user `deinit` if the type is a class declaring one.

Emission at each scope exit, in order:

1. `defer` bodies, reverse registration order
2. locals, reverse declaration order

Both emit before **every** terminator leaving the scope — fall-through `br`,
`return`, and the `br` of `break`/`continue`. With no unwinder the edge set is
finite and static.

`defer` is block-scoped, so registration is static: no runtime defer list, no
mask, just duplication of the deferred call onto each exit edge.

A transferred binding is omitted from step 2. No flag is set and none is read —
this is the whole reason conditional transfer is a compile error.

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

`(T, string)` is a `struct` with a generated ident, returned by `sret`. Always —
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
function, since the slot is a local `alloca` with no escaping address. That is a
codegen optimization, not a VIR guarantee (§21.2).

---

## 9. Control Flow

### 9.1 Loops

Every loop lowers to a `while` shape, then to blocks.

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

`br_if`. Short-circuit is a branch, not a select. A lane predicate can never
reach `&&`/`||`/`if` at the source level, so no such branch is emitted for one.

### 9.3 `switch`

Dense integer or enum-tag cases → VIR `switch`. Sparse → compare chain. String
cases → length compare then an inline byte compare. `fallthrough` → `br` to the
next case block. An exhaustive enum `switch` emits no default edge; the
verifier's required default label targets a block ending in `unreachable`.

### 9.4 Enums

Unit enum: the discriminant integer; `as intN` is a no-op reinterpretation.

Payload enum: `struct E(tag iN, payload array[i8, N])`, `N` the largest variant's
size, alignment the largest variant's. Case bindings are `field.ptr` + cast into
the payload — views, not copies. Copy and drop switch on the tag and recurse into
the live variant only.

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

Relaxed retain, acq-rel release: retain only needs atomicity; release must
synchronize with every prior release so the destructor sees all writes. The weak
count starts at 1 and is owned collectively by the strong count, so strong-zero
decrements weak exactly once.

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

Requiring `deinit` to reach its owner through `upgrade` is what makes this
sound: a direct back-edge would be a strong count already at zero.

---

## 11. Containers

### 11.1 `string`

`{ptr, len}` over UTF-8, no NUL. Literals are a `global` byte array plus a
constant length; `addr .Lstr0` is the pointer.

**A bare copy duplicates the bytes.** The alternative is a refcount header,
which puts atomics on a type whose spelling contains no `shared` — a cost
invisible in the source, violating §0.1. `foundation_spec.md` §5's "may be
shared or interned" license is therefore unused.

A copy never allocates when the destination is a parameter and the source
outlives the call, but that is a front-end optimization, not a representation
change.

### 11.2 `[]T`

`{ptr, len, cap}`. Growth is amortized doubling through `rt_realloc`. `push` may
reallocate, which is why interior pointers do not exist and slices are
lifetime-checked instead.

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
emitted for it.

### 11.3 `map[K]V`

One `ptr` to a type-erased `rt` table. The front end supplies `sizeof(K)`,
`sizeof(V)`, and four function pointers: `_Vhash_K`, `_Veq_K`, `_Vdrop_K`,
`_Vdrop_V` (null when trivial).

Erasure here rather than monomorphization: a hash table is ~2 KB of code with no
per-type specialization payoff beyond the comparison, which is already a pointer.

`m[k] = nil` lowers to `rt_map_erase` — the one place `nil` appears outside
`typed_ptr`.

### 11.4 Slice views

`{ptr, len}`, borrowed, never deep-copied, never dropped. The Law of
Exclusivity forbids mutating or transferring the viewed buffer while the view is
live — enforced in the front end, invisible in VIR (§21.4). A view that is the
destination of a vector store (§12.3) carries a `mut` borrow instead; that is
front-end bookkeeping and leaves no trace here beyond the store.

---

## 12. Vectors

`vector[T, N]` lowers directly to VIR's native `vec[T, N]` register class.
Unlike every other Vertex aggregate it is **not** memory-only — §5.3 does not
apply to it.

### 12.1 Type and tier

| Vertex | VIR |
| --- | --- |
| `vector[T, N]` | `vec[T, N]` |
| lane predicate | `vec[i1, N]` |

Legality is gated by the target's feature tier: `vec[T, N]` is legal only if `N`
fits the tier's native width for `T`. Where the tier is narrower than the source
`N`, the front end splits into `ceil(N / W)` operations over `vec[T, W]` before
VIR sees the wider form, and every opcode below is emitted once per piece. On a
tier with `W = 1`, every vector operation lowers to `N` scalar instructions —
the same shape a hand-written scalar loop produces.

### 12.2 Construction

| Source (`semantics.md` §10.4) | VIR |
| --- | --- |
| splat, constant argument | `const.vec[T,N]`, or a `global` plus `load.vec[T,N]` |
| splat, runtime argument | `splat.vec[T,N] v` — opcode missing, §21.11 |
| load, `VectorType(buf, i)` | bounds compare (`i + N` against length) + `br_if` → `trap`, then `index.ptr` + `load.vec[T,N] p, align E`, `E` being `T`'s element alignment — never the vector's natural alignment |
| lane conversion | the destination-explicit conversion opcode with a `vec[T,N]` destination; float→int traps per-lane exactly as its scalar counterpart does |

A constant index provably out of range on a fixed array is a compile-time error
and emits no runtime check.

### 12.3 Store

`copy(view, vec_value)` lowers to `index.ptr` + `store.vec[T,N] p, v, align E`,
`E` again the element alignment. This bypasses the `memcopy`/`memmove` path
entirely — a vector store is a single instruction.

### 12.4 Operations

| Source | VIR |
| --- | --- |
| `+ - * &+ &- &* & \| ^ ~ << >>` | the identical scalar opcode, operands and result typed `vec[T,N]` |
| `== != < <= > >=` | the identical comparison opcode, yielding `vec[i1, N]` in place of `i1` |
| `min`/`max` | `min.fN`/`max.fN` for float `T`; `smin`/`smax`/`umin`/`umax` for integer `T` |
| `clamp(v, lo, hi)` | `max` then `min`, both vector forms |
| `blend(m, a, b)` | `select.vec[T,N] m, a, b` — opcode missing, §21.11 |
| `v[k]`, constant `k` | `extract.vec[T,N] v, k` — opcode missing, §21.11 |

Integer `/` and `%` on a vector are rejected in the front end and never reach
this table.

### 12.5 The lane predicate is never in memory

A `vec[i1, N]` value lives only in a register binding, covered by the join
convention like any other named value. It is never the target of
`field.ptr`/`index.ptr`, never a `global` or `const` initializer, and never a
`struct` member. The backend's representation choice — a mask register, or an
all-ones/all-zeros `vec[iN,N]` — is target-dependent codegen under a fixed
opcode meaning, and this document takes no position on it.

### 12.6 Ownership and cost

`vec[T,N]` and `vec[i1,N]` are thin: passed and returned as any scalar is,
copied by register move, torn down by nothing. No `_Vdrop_T` is ever generated
for one, and a struct containing a vector field is not thereby non-trivial.

### 12.7 Boundary rejection

Vectors are rejected in the front end before reaching a `declare` boundary and
before reaching a `gpu` or `npu` signature or body, so nothing in §18 or §19
special-cases them.

---

## 13. Closures

### 13.1 Representation

`struct _Vfn(ptr, ptr)` — code, env. `code` always takes the environment as its
first parameter.

Capturing closures allocate `env` with `rt_alloc` at creation and own it: the
closure's `_Vdrop` drops each captured value then frees `env`. Captures are
copied in by value at creation.

`env` is heap because a closure may outlive its frame
(`func makeAdder(n: int32) -> func(int32) -> int32`). Escape analysis may demote
a non-escaping `env` to an `alloca` — an optimization, not a representation.

Assigning to a capture is a compile error, so `env` is written once and never
mutated, and the backend may treat it as immutable.

### 13.2 Non-capturing functions as values

A non-capturing function used as a `func` value gets `_Vthunk_f(env ptr, ...)`,
which ignores `env` and `tailcall`s the real function. The `_Vfn` pair is
`{addr _Vthunk_f, null}`. The alternative — a null-`env` check at every indirect
call — costs more.

### 13.3 At the foreign boundary

Only a non-capturing function crosses. The value passed is `addr f` — the real
function, not the pair and not the thunk. Non-capturing-ness is known
statically, so there is nothing to strip at runtime.

---

## 14. Generics

Monomorphization, one VIR `fn` per instantiation (§3.1 naming, §3.3 linkage).

* A generic never instantiated emits nothing.
* A method-constraint call lowers to a direct `call` on the concrete type. No
  vtable, no dictionary, no `fnsig` indirection.
* Copy/drop cost is the concrete type's, which is why the cost lint fires per
  instantiation.
* Recursive instantiation is bounded by the front end's depth limit before
  lowering runs.

---

## 15. Traps, Panic, Undefined Behavior

Free — VIR already traps:

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

`panic` satisfying "every path returns" is exactly VIR's `noreturn` +
`unreachable` requirement, so the two rules discharge each other.

**Arithmetic wrapping.** `+`, `-`, `*` lower to `add`/`sub`/`mul`, which wrap
modulo 2^N. `&+`, `&-`, `&*` lower to the same instructions; the operators are
distinguishable only in constant expressions (§21.7).

**`typed_ptr` UB.** Out-of-bounds `.add`, cross-block `.diff`, stale `delete`,
reading an unzeroed block — all lower to plain `index.ptr`/`load`/`rt_free` with
no check, landing in VIR UB categories 1, 2, and 8. Nothing here narrows them.

---

## 16. Async

### 16.1 Shape

An `async` function becomes:

1. `struct _Vframe_f(state i32, <locals live across a suspend>, <child frames>, result)`
2. `fn _Vresume_f(frame ptr) i32` — one block per resume point, dispatched by a
   `switch` on `state` at entry. Returns `0` = complete, `1` = suspended.
3. A stub `fn f(...)` that initializes the frame

State lives in the frame in memory, so there are no phi nodes to reconstruct and
no register allocation to restore across a suspend.

### 16.2 `await`

Split the block. Store live locals into the frame, set `state`, return `1`. The
resume block reloads. Only values live *across* the suspend go in the frame —
the source of `async.md` §7.1's memory-footprint claim.

### 16.3 Child frames

`await g()` where `g` is `async` embeds `_Vframe_g` inside `_Vframe_f`. One
allocation covers a whole await chain.

**Consequence: recursive `async` is a compile error** — the frame size would not
be computable. Vertex has no boxed-future type and should not grow one; spawn
instead, which allocates a fresh frame (§16.5, §21.6).

### 16.4 `main`

`main` is the reactor root, lowered as an async function whose frame is an
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

`rt_readable(fd, frame)` / `rt_writable(fd, frame)` return immediately-ready or
suspend. These two are the entire reactor seam; a custom reactor reimplements
them and nothing else.

---

## 17. Threads, Channels, `select`

### 17.1 `thread f(x)`

1. `alloca` an argument pack, move arguments in
2. `rt_chan_new(1, sizeof(T), _Vdrop_T)`
3. `rt_thread_spawn(addr _Vtramp_f, pack)`

`_Vtramp_f(arg ptr) void` unpacks, calls `f`, sends the result, closes the
channel, frees the pack.

### 17.2 Channels

One `ptr` to an `rt` channel. Type-erased core; element size and an element drop
function are supplied at construction.

The drop function is what makes ownership sound across the channel: `send` is an
owning position, so the value moves into the buffer and the receiver inherits
teardown; values still buffered at `rt_chan_drop` are dropped by the channel.

`chan[shared T]` is rejected in the front end because channel element types need
a zero value, which is also why `rt_chan_try` can write a zeroed slot on failure
without knowing `T`. `chan[vector[T,N]]` is legal by the same rule; a channel of
the lane predicate is not, since the predicate cannot be named as an element
type at all.

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
reactor-registered). The no-mixing rule is what makes the choice static.

---

## 18. Interop

The `declare` block's build tag and variant tag pick the call shape. In every
case the abstract handle is a `ptr` and no foreign layout is described.

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
A runtime call rather than a dynamically-sized `alloca` because VIR's `alloca`
is a fixed frame slot, and the case is already paying a foreign call (§21.8).

### 18.4 Objective-C (`declare framework`, `darwin`)

`objc_msgSend` with a cached selector. Selectors cannot be `global` initializers
(VIR forbids calls in initializers), so each is a lazily-filled `global`:

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
A C++ exception escaping into Vertex is UB, and every foreign declaration is
effectively `nounwind` by fiat. `"no-exceptions"` is therefore the only
configuration with defined behavior across the boundary (§21.9).

### 18.6 `abstract` → `typed_ptr T`

Memory-flat imports: a no-op reinterpretation, since the handle already is an
address. Object-graph imports (JS, Darwin frameworks): rejected in the front
end; nothing reaches lowering.

---

## 19. Device Code

**`gpu` and `npu` bodies do not lower to VIR.** VIR is CPU-only by charter; both
markers target a separate IR, **GVIR** (GPU Vertex IR), specified in `gvir.md`.
Everything about device bodies — their restricted constructs, their type
systems, their launch shapes, and their runtime entry points — belongs to that
document, not this one.

The only obligation this document carries is the exclusion itself: a device body
never reaches any table above, and the front end rejects `vector[T, N]` in a
device signature or body (§12.7) before lowering begins.

---

## 20. Tests

A `build test` file compiles to its own module with an `entry`.

| Form | Lowering |
| --- | --- |
| `test -> Expected(T, "...")` | exported `fn`; runner compares emitted formatting to the literal |
| `test` with no expectation | exported `fn`; passes if it returns |
| `test -> Expected(error)` | **not lowered** — a compile-time assertion; a body that compiles is a test failure |
| `test -> Expected(error, "...")` | not lowered; additionally matches the diagnostic |

`Expected(error)` never producing code is why `diagnostics.md` is a real
dependency: the assertion is on diagnostic text, which lives nowhere in this
pipeline.

---

## 21. What This Document Forces

Changes or ratifications needed elsewhere. The lowering above assumes all of it.

**21.1 Reserve the `_V` prefix** — `semantics.md` §1.8. An identifier beginning
`_V` may not be declared. One line.

**21.2 `foundation_spec.md` §9 is wrong on tuple returns.** All multi-value
returns are `sret` (§8); register-pair returns are a backend promotion.

**21.3 Monomorphized instances duplicate across modules.** No
`linkonce`/COMDAT in VIR. **Recommend accepting** — dedup is a size
optimization; VIR's flat-namespace guarantee is worth more.

**21.4 Exclusivity is not transmitted to VIR.** Shared parameters, `mut`
parameters, and slice borrows all pass as bare `ptr`; the front end proves
non-aliasing and discards the proof. **Proposal:** add `noalias` and `readonly`
param attributes to VIR. Highest-value item on this list.

**21.5 `js` and `wasm` cannot lower to VIR** — VIR admits real silicon only.
**Recommend** a parallel `wasm-lowering.md`. This document is native-only until
it exists.

**21.6 Recursive `async` must be a compile error** (§16.3). New front-end rule;
the diagnostic should point at spawning.

**21.7 `&+`/`&-`/`&*` lower identically to `+`/`-`/`*`.** They differ only in
constant expressions. **Recommend** making plain runtime overflow trap so the
operators do real work; a language decision, but lowering is where it shows.

**21.8 Three VIR spellings need pinning** — `alloca` operand form, `index.ptr`
scaling, `cmpxchg` result shape (§0.1). Also whether `alloca` can be dynamically
sized, which would remove the `rt_cstr_new` round trip (§18.3).

**21.9 Reconsider `exceptions on` as the C++ default.** An escaping C++
exception is UB with no unwinder to make it otherwise. **Recommend** defaulting
to no-exceptions.

**21.10 Ratifying `todo.md` §2**

| Open decision | Lowering's answer |
| --- | --- |
| §2.1 partial moves | **Keep the conservative rule.** Per-field liveness needs per-field drop flags, contradicting §0.2. |
| §2.2 subscript overlap | Lowering-neutral; decide on ergonomics. |
| §2.3 `deinit` on structs | Lowering-neutral; only the trivial/non-trivial classification shifts. |
| §2.4 channel zero values | **Confirmed necessary** — `rt_chan_try` writes a zeroed slot without knowing `T`. |

**21.11 Three vector opcodes VIR does not name.** Arithmetic, comparison, and
min/max reuse scalar opcodes (§12.4); these three have no scalar analog:

* `splat.vec[T,N] v` — broadcast a runtime scalar into every lane (constants are
  already covered by `const.vec[T,N]`).
* `extract.vec[T,N] v, k` — read lane `k`, `k` a compile-time immediate.
* `select.vec[T,N] m, a, b` — per-lane select keyed by a `vec[i1,N]` mask; the
  entire lowering of `blend`. Not composable from bitwise ops without exactly
  the implicit narrowing `semantics.md` §10.7 forbids.

All three are single-instruction-shaped and introduce no new register class,
memory form, or runtime question. **Recommend adding all three** — without them,
§12.2 and §12.4 name opcodes that do not exist.