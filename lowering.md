# Vertex Lowering

Source construct → VIR. One section per construct, each ending in VIR.

`grammar.md` and `semantics.md` are normative for the source language; the VIR
specification (`README.md`) is normative for the target. This document is
normative only for the mapping between them, and wins over any chapter file on
lowering questions.

---

## 0. The Contract

1. **Every cost is decided here.** A construct whose cost is invisible in this
   document was mis-modelled by the front end.
2. **No lowering introduces a runtime question.** No drop flags, no type tags, no
   dispatch tables, no unwinder. Anything that would need one is a front-end
   error, not a runtime mechanism.
3. **VIR is CPU-only.** `gpu`/`npu` bodies (§20) and the `js`/`wasm` build tags
   (§22.5) never reach VIR.
4. **Nothing here relaxes a static rule.** Where `semantics.md` promises a trap or
   a panic, this document emits it, even when the emission costs an instruction.

### 0.1 Spelling assumptions

VIR fixes instruction shape but leaves three operand spellings underspecified.
This document writes them as:

| Written here | Meaning |
| --- | --- |
| `p = alloca.ptr N, align A` | frame slot of `N` bytes at alignment `A` |
| `q = index.ptr p, n` | `n` is a **byte** offset; the front end scales by `sizeof(T)` |
| `got = cmpxchg.iN p, exp, new, succ, fail` | yields the observed value; success is `got == exp` |

If VIR settles on different spellings, only these three lines change (§22.8).

---

## 1. The VIR Surface Vertex Uses

| VIR feature | Used by |
| --- | --- |
| `iN`, `fN`, `ptr` | every scalar (§4.1) |
| `vec[T,N]` | `vector[T,N]` construction, arithmetic, comparison, `blend`/`min`/`max`/`clamp` (§15) |
| `struct`, `array[T,N]` | aggregates, in memory only |
| `alloca.ptr` | every forced slot, every temporary aggregate |
| `field.ptr`, `index.ptr` | field and element addressing |
| `load`/`store`, `memcopy`/`memmove`/`memset` | copies, teardown, `copy`/`zero` |
| `switch` | `switch` statements, enum tags, async state dispatch |
| `br_if` + `trap` | every check in §11 |
| `sdiv`/`udiv`/`srem`/`urem` | `/` and `%` — trap on zero and on `INT_MIN / -1` for free |
| `saddo`/`uaddo`/`ssubo`/`usubo`/`smulo`/`umulo` | overflow traps on `+ - *` and unary `-` (§11.1) |
| `stoint`/`utoint` | float→int, traps out of range for free |
| atomics + `fence` | `shared T` / `weak T` refcounts and the Objective-C selector cache |
| `call.<fnsig>` | closures, C++ and COM vtables |
| `tailcall` | closure thunks (§16.2) |
| `noreturn` + `unreachable` | `panic` (§11.4) |
| `loc` | one per source statement |

**Unused, and why:**

| VIR feature | Why Vertex never emits it |
| --- | --- |
| `valist`, `alloca.valist`, `va_start`/`va_arg`/`va_end` | Vertex calls C-variadics but cannot define one (§19.2); a Vertex variadic is a slice (§7) |
| `syscall` | reached through an ordinary `declare module` extern, never directly |
| `f16` | no source spelling |
| `i128` | no source spelling; `int`/`uint` are pointer-width (§4.1) |
| `i1` outside comparison results | `bool` is `i8` (§4.1); the lane predicate's `vec[i1,N]` is comparison-only (§15.5) |
| saturating `uadd_sat`/… | Vertex has trapping (`+`) and wrapping (`&+`) forms only |

---

## 2. Modules and the Runtime

### 2.1 Module shape

One VIR module is one Vertex **package**; `namespace` is the package path.
VIR's fixed section order (VIR spec §2.1) is not a formatting preference — it
enables one-pass verification, and it means the emitter cannot stream in source
order. Emission runs in six collection passes and then writes:

```
module <package>
namespace "<path>"
target <arch> <os> <abi> [tiers]
  struct   — layouts (§4.2), boundary tuples (§8), async frames (§18), _Vfn
  fnsig    — every indirect-call shape: closures, C++/COM vtable slots, rt callbacks
  const    — nothing today; string literal lengths are immediates
  global   — string literal bytes, Objective-C selector caches (§19.4)
  link     — "vertexrt", plus one line per declare block's library
  extern   — the rt group (§2.2), plus one group per foreign library
  import   — one per imported package
  fn       — declarations in dependency order
```

`target` is not optional for Vertex output: every module links `vertexrt`, and
VIR requires a target line whenever `link` is present.

**Declare-before-use** (VIR spec §2.2) is the one ordering constraint the front
end must actively satisfy. Vertex top-level declarations are order-independent
(`semantics.md` §1.1) and may be mutually recursive, so `fn` definitions are
emitted in dependency order with mutual recursion broken by the fact that only
*bodies* reference each other — a `fn`'s signature is fixed before any body is
written. Types recurse only through one-word indirections (`semantics.md` §3.4),
so `struct` emission always terminates.

### 2.2 The runtime module — `builtins/rt`

VIR has no built-in heap, so allocation, string comparison, the map table, the
channel core, threads, and the reactor are declared externs. This is the complete
list; `rt` ships as a static library built from Vertex + VIR.

```vir
link static "vertexrt"

extern "vertexrt":
  fn rt_alloc(size i64, align i64) ptr
  fn rt_alloc_zeroed(size i64, align i64) ptr
  fn rt_realloc(p ptr, size i64, align i64) ptr
  fn rt_free(p ptr, align i64) void
  fn rt_panic(msg ptr, len i64) void noreturn

  fn rt_str_cmp(a ptr, alen i64, b ptr, blen i64) i32
  fn rt_cstr_new(p ptr, len i64) ptr
  fn rt_cstr_free(p ptr) void

  fn rt_map_new(ksz i64, vsz i64, hash ptr, eq ptr, kdrop ptr, vdrop ptr) ptr
  fn rt_map_get(m ptr, k ptr) ptr
  fn rt_map_set(m ptr, k ptr, v ptr) void
  fn rt_map_erase(m ptr, k ptr) void
  fn rt_map_len(m ptr) i64
  fn rt_map_next(m ptr, cursor i64, kout ptr, vout ptr) i64
  fn rt_map_free(m ptr) void

  fn rt_chan_new(cap i64, esz i64, edrop ptr) ptr
  fn rt_chan_send(c ptr, v ptr) void
  fn rt_chan_try_send(c ptr, v ptr) i32
  fn rt_chan_recv(c ptr, out ptr) i32
  fn rt_chan_try_recv(c ptr, out ptr) i32
  fn rt_chan_close(c ptr) void
  fn rt_chan_drop(c ptr) void
  fn rt_select(descs ptr, n i64, has_default i32) i64
  fn rt_select_await(descs ptr, n i64, has_default i32, frame ptr) i64

  fn rt_thread_spawn(entry ptr, arg ptr) i64
  fn rt_yield() void
  fn rt_task_spawn(frame ptr, resume ptr, esz i64) ptr
  fn rt_task_await(c ptr, out ptr, frame ptr) i32
  fn rt_reactor_run(root ptr, resume ptr) i32
  fn rt_readable(fd i32, frame ptr) i32
  fn rt_writable(fd i32, frame ptr) i32
end
```

Three notes on the shape of that list:

* **Free is unsized.** `delete[T](p)` carries no count (`memory.md` §11.2), and
  `resize[T](p, count)` carries only the new one, so the block size is not
  recoverable at either call site. `rt` must therefore recover a block's size
  class from its address — segment metadata, not a per-block header. This is an
  allocator constraint the source language forces; see §22.3.
* **`rt_alloc` returns null on failure.** Container paths panic on null
  (`foundation.md` §22.2); explicit `new[T]` checks it and builds a boundary
  tuple (§14.2).
* **Refcounting is not in this list.** `shared T` retain and release are inline
  VIR atomics (§13.2) — two or three instructions with no bookkeeping.
* **`rt_chan_try_recv` distinguishes empty from closed** (status 1 vs 2), but
  `.tryReceive()` collapses both into one non-empty string. The distinction
  exists in rt and is dropped at the boundary; that is exactly the gap
  `channels.md` §6 records, and closing it needs no runtime work.

---

## 3. Names and Symbols

### 3.1 Vertex → VIR identifiers

| Vertex | VIR ident |
| --- | --- |
| `func add` | `add` |
| `func (w: Widget) rename` | `Widget_rename` |
| `func (w: Widget) init` | `Widget_init`; named: `Widget_init_withRect` |
| `func (w: Widget) deinit` | `Widget_deinit` |
| `smaller[float64]` | `smaller__f64` |
| `Pair[int32, string]` | `Pair__i32_str` |

Method names live in no scope (`semantics.md` §2.1), so a method `read` and a
function `read` in one package cannot collide before mangling and do not collide
after it. Type arguments encode as their VIR type name (`i32`, `f64`, `ptr`) or a
named type's own ident; nested instantiations recurse. Uniqueness within the
module is guaranteed by monomorphization (§17).

### 3.2 Compiler-synthesized names

Reserved prefix **`_V`** (§22.1).

| Name | Purpose |
| --- | --- |
| `_Vcopy_T` | synthesized deep copy (§7.1) |
| `_Vdrop_T` | synthesized teardown (§7.3) |
| `_Veq_T` | structural `==` (§11.3) and `map` key equality (§13.3 — §14.3) |
| `_Vhash_T` | `comparable` support for `map[K]V` (§14.3) |
| `_Vthunk_f` | non-capturing function used as a value (§16.2) |
| `_Vnullfn` | the panic target of a zero `func` value (§11.5) |
| `_Vresume_f` | async state machine body (§18) |
| `_Vtramp_f` | thread entry trampoline (§19 — §18.5) |

### 3.3 Export and mangling

`export` on the VIR `fn`/`global` for every package-level Vertex declaration —
Vertex has no visibility modifier (`semantics.md` §1.1), so there is no second
case. VIR's Itanium-style mangling applies on top of the idents in §3.1; nothing
pre-mangles.

Monomorphized instances are **not** exported. VIR has no `linkonce`/COMDAT, so
two modules instantiating `smaller[int32]` would collide in the flat namespace;
each module emits its own internal copy (§22.4).

`main` in package `main` emits `entry`, which VIR gives a bare symbol even in a
namespaced module (§18.4).

---

## 4. Layout

### 4.1 Scalars

| Vertex | VIR |
| --- | --- |
| `int8`…`int64`, `uint8`…`uint64`, `byte` | `i8`…`i64`; signedness lives in the opcode |
| `int`, `uint` | `i32` or `i64` by target pointer width |
| `float32`, `float64` | `f32`, `f64` |
| `bool` | `i8`, values 0 and 1 |
| `char` | `i32` |
| `typed_ptr T`, `abstract`, `unique T`, `shared T`, `weak T` | `ptr` |
| unit enum | the discriminant's width |
| `vector[T, N]` | `vec[T, N]` — a register class, not an aggregate (§15.1) |

`bool` is `i8` because `i1` has no ABI-agreed memory representation; comparisons
yield `i1` and widen at the store. `vec[T,N]` has no such problem — it maps to a
hardware vector register and is never stored in a form the ABI must agree on
beyond element-wise byte layout.

`int`/`uint` are distinct types from `int64`/`uint64` even where the widths agree
(`semantics.md` §2.3); they mangle distinctly (§3.1) and are otherwise identical
after lowering.

### 4.2 Aggregates

| Vertex | VIR |
| --- | --- |
| `struct S` / `class S` | `struct S` — identical, no header, no vptr |
| `[N]T` | `array[T, N]` |
| tuple `(A, B)` | `struct` with a generated ident |
| `string` | `struct _Vstr(p ptr, len i64)` |
| slice `[]T` view | `struct _Vslice(p ptr, len i64)` |
| `[]T` dynamic | `struct _Vvec(p ptr, len i64, cap i64)` |
| `map[K]V` | `ptr` (§14.3) |
| `chan T` | `ptr` (§19.2) |
| range `a..b` | `struct _Vrange_iN(lo iN, hi iN)`, and only ever an unmaterialized loop pair (§10.1) |
| `func` value | `struct _Vfn(code ptr, env ptr)` |
| payload enum | `struct` — tag + `array[i8, N]` (§10.4) |

Field order is declaration order with natural alignment. Vertex adds no
reordering: order is observable through interop `byval` and through `field.ptr`
offsets a foreign header may assume. A class is byte-for-byte a struct
(`foundation.md` §27), so nothing distinguishes the two at this level.

`vector[T, N]` and the lane predicate are absent from this table — they are
register-class types (§4.1), never memory aggregates.

### 4.3 Aggregates are never values

VIR aggregates are memory-only. Forced consequences:

* Every aggregate parameter is `ptr` or `byval[S]`.
* Every aggregate return is `sret[S]` on a `void` function — boundary tuples
  included (§8).
* Every aggregate temporary is an `alloca`.
* "Copying" an aggregate is `memcopy`, never an assignment.

**This does not apply to `vector[T, N]` or the lane predicate** — both are
register-class types held in named values, passed and returned by value, with no
`sret`, `byval`, or size-forced `alloca` (§15).

---

## 5. Bindings and Slots

| Source | Lowering |
| --- | --- |
| `let x = e` | a named VIR value; no slot |
| `var x = e` | a named VIR value **unless** a slot is forced |
| `var x: T` (no init) | zeroed slot, or a zero-valued name (`semantics.md` §3.3) |
| `_` | expression evaluated, result discarded |

A slot is forced when the binding is: passed to a `mut` parameter or receiver,
the operand of `addr`, an aggregate (§4.3), captured by a closure that outlives
it, live across an `await` (§18.2), or an operand of `===` — class identity is
the slot address.

The join convention carries a reassigned name across blocks without memory, so a
slot is needed only when an *address* is. That is unobservable except through
`===`, which is why `===` is on the list.

**Every `alloca` is emitted in the entry block.** VIR allocas are per-execution
and accumulate per loop iteration (VIR spec §5.1), so a slot written inside a
loop body is allocated once, before the loop, and reused. This is sound because a
loop-body local's teardown (§7.3) runs on every back edge, leaving the slot dead
at the top of each iteration. Vertex has no dynamically sized local, so no
`alloca` ever depends on a runtime value.

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

## 6. Calls — the Three Conventions

| Signature | VIR parameter | Caller emits |
| --- | --- | --- |
| `x: T` (shared) | thin → value; aggregate → `ptr` | nothing |
| `x: mut T` | `ptr` | address of the caller's slot |
| `x: var T` (owning) | thin → value; aggregate → `byval[S]` | transfer: nothing; copy: §7.1 first |

`vector[T, N]` and the lane predicate are thin (§15.6) and follow the first and
third rows exactly like any scalar.

**Shared aggregates pass as a bare `ptr`.** VIR has no `noalias` or per-parameter
`readonly`, so exclusivity (`semantics.md` §8.4) is discharged in the front end
and is not transmitted to VIR; the optimizer cannot exploit it (§22.6).

**Owning aggregates use `byval[S]`.** VIR requires the caller's object to stay
live and unmutated for the call, which is exactly true after a transfer. A large
inline aggregate transfer is therefore a `memcopy` — O(1) in *ownership* terms
(`ownership.md` §11) but not in instructions; the size is the declared type's,
not a payload's.

Arguments evaluate left to right; VIR is sequential, so emission order *is*
evaluation order. Named arguments resolve to positional order in the front end
and leave no trace (`semantics.md` §5.4).

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
| only scalars, fixed arrays of scalars, slice views, `typed_ptr`, `abstract`, unit enums, non-capturing `func`, `vector[T,N]`, lane predicate | **trivial** — register move or `memcopy` |
| `string`, `[]T`, `map[K]V`, capturing closure, `unique T` | **deep** — `_Vcopy_T` |
| `shared T`, `weak T`, `chan T` | **retain** — atomic increment |
| a class declaring `deinit`, or a field of any of the above | deep |

One `_Vcopy_T` per type, called at the copy site, never inlined: a bare copy is
already the documented-expensive path (`ownership.md` §11), and duplicating its
body multiplies that.

`_Vcopy_T` signature: `fn _Vcopy_T(dst ptr sret[T], src ptr) void`.

### 7.2 Transfer

Emits nothing. A transfer is the ordinary by-value pass or store, made legal by
liveness; its entire lowering is the *absence* of a `_Vdrop_T` call at the
source's original end of liveness.

### 7.3 Teardown

`_Vdrop_T(p ptr)` per non-trivial type. Body: the user `deinit` first if the type
is a class declaring one, then fields in reverse declaration order
(`semantics.md` §7.2).

Emission at each scope exit, in order:

1. `defer` bodies, reverse registration order
2. locals, reverse declaration order

Both emit before **every** terminator leaving the scope — fall-through `br`,
`return`, and the `br` of `break`/`continue`. With no unwinder the edge set is
finite and static.

`defer` is block-scoped and its callee and arguments are evaluated at the `defer`
statement, so registration is static: no runtime defer list, no mask, just
duplication of the deferred call onto each exit edge, with the evaluated
arguments held in slots.

A transferred binding is omitted from step 2. No flag is set and none is read —
this is the whole reason conditional transfer is a compile error
(`semantics.md` §8.3).

**`panic` runs none of this.** Deferred calls do not run and no `deinit` runs
(`semantics.md` §10), which is consistent for free: `rt_panic` is `noreturn` and
the block ends in `unreachable`, so there is no exit edge to emit onto.

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
`(int32, string)` included. A bare `string` result (`foundation.md` §35.1) is an
ordinary `_Vstr` return and gets no tuple.

```vertex
func parseInt(s: string) -> (int32, string)
let n, err = parseInt(s)
```

```vir
struct _Vt_i32_str(v i32, ep ptr, elen i64)

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

Failure costs exactly what success costs: the same stores into the same slot. The
error path's value slot is the type's zero (`foundation.md` §35.5), which is a
`memset` or a zeroed store, never a partially built object.

A backend may promote the `sret` slot to a register pair for a non-`export`
function, since the slot is a local `alloca` with no escaping address. That is a
codegen optimization, not a VIR guarantee (§22.2).

---

## 9. Zero Values

`semantics.md` §3.3 gives every type a zero value and states that the only memory
in a Vertex program that is not zero-initialized is a block from
`new(…, zeroed: false)`. Lowering discharges that with `memset` or zeroed stores,
with three cases where the zero is not merely bytes:

| Zero of | Bytes | What makes it behave as specified |
| --- | --- | --- |
| `typed_ptr T` | null | nothing — `nil` *is* null (§14) |
| `func` type | `_Vfn(null, null)` | a null-code check at every indirect call (§11.5) |
| `unique T`, `shared T`, `weak T` | null | a null check on every read through the handle (§11.5) |
| `chan T` | null | `rt` treats a null channel as closed and empty |
| enum | first variant, payload zeroed | nothing — the tag is 0 |

Field defaults are **not** part of a zero value; they belong to construction
(`semantics.md` §7.2) and are evaluated at each composite literal or `init` call
for each omitted field.

---

## 10. Control Flow

### 10.1 Loops

Every loop lowers to a `while` shape, then to blocks. A range is never
materialized as the `_Vrange` struct — it becomes the counter's bounds.

| Source | Iteration state |
| --- | --- |
| `for i in a..b` | one counter |
| `for x in arr` | counter + `index.ptr` |
| `for i, x in arr` | counter + `index.ptr` |
| `for mut x in arr` | counter; the body writes through `index.ptr` |
| `for var x in arr` | counter; element moved out per iteration; see below |
| `for c in s` | byte cursor + UTF-8 decode |
| `for b in s.bytes()` | byte cursor |
| `for k, v in m` | `rt_map_next` cursor, `-1` terminating |

A consuming `for` (`ownership.md` §3.4) moves each element out and emits no
per-element drop. The container is dead after the loop, and its teardown is a
header drop **plus a drop of the unvisited tail** `[i, len)` — which is exactly
what `break` out of a consuming loop leaves behind. The counter is already live,
so this costs a loop on the exit edge and nothing on the hot path.

### 10.2 `if`, `&&`, `||`

`br_if`. Short-circuit is a branch, not a select. There is no truthiness
(`semantics.md` §5.1), so the operand is already an `i8` `bool` and narrows to
`i1` with a compare against zero — or, where it came from a comparison, is used
directly before its widening store.

A lane predicate can never reach `&&`, `||`, or `if` at the source level
(`accel.md` §3.3), so no such branch is emitted for one.

### 10.3 `switch`

Dense integer or enum-tag cases → VIR `switch`. Sparse → a compare chain. String
cases → `rt_str_cmp` against each literal, in source order, after a length
compare that rejects most candidates without a call. `fallthrough` → `br` to the
next case block.

An exhaustive enum `switch` emits no default edge of its own; VIR's `switch`
terminator requires a default label, so it targets a block ending in
`unreachable`.

### 10.4 Enums

Unit enum: the discriminant integer; `as intN` is a no-op reinterpretation, and
there is no reverse direction to lower (`foundation.md` §26.4).

Payload enum: `struct E(tag iN, payload array[i8, N])`, `N` the largest variant's
size, alignment the largest variant's. Case bindings are `field.ptr` plus a cast
into the payload — views, not copies, and not assignable through
(`semantics.md` §6.4). Copy and drop switch on the tag and recurse into the live
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

## 11. Operators, Traps, and Panics

VIR wraps on integer overflow and masks shift counts; Vertex traps on both
(`semantics.md` §5.5). The difference is this section's whole content.

### 11.1 Arithmetic

| Vertex | VIR |
| --- | --- |
| `a + b` on `iN` | `add` **plus** `saddo`/`uaddo` + `br_if` → `trap` |
| `a - b`, unary `-a` | `sub`/`neg` plus `ssubo`/`usubo` on `(0, a)` for the unary form |
| `a * b` | `mul` plus `smulo`/`umulo` |
| `a &+ b`, `a &- b`, `a &* b` | `add`/`sub`/`mul`, no check — the operators now do real work |
| `a / b`, `a % b` | `sdiv`/`udiv`/`srem`/`urem` — zero and `INT_MIN / -1` trap for free |
| float arithmetic | the `fN` opcode; IEEE, no trap, no fast-math |
| `a << b`, `a >> b` | a `ult` of `b` against the left operand's width + `br_if` → `trap`, then `shl`/`lshr`/`ashr` |
| `& \| ^ ~` | `and`/`or`/`xor`/`not` |

The overflow opcodes yield the flag, not the result, so a checked `+` is two
instructions plus a branch. Signedness picks between the `s` and `u` forms from
the operand type, exactly as it does for `sdiv` vs `udiv`.

### 11.2 Conversions

`as` is destination-explicit in VIR. Integer→integer is `trunc`/`sext`/`zext`;
integer→float and float→float are the corresponding conversion opcodes;
float→integer is `stoint`/`utoint`, which trap out of range including NaN and
±Inf, discharging `semantics.md` §5.5's last row for free. `typed_ptr` ↔ integer
is `bitcast` with an exact `usize` match. `typed_ptr T as typed_ptr U` and
`abstract as typed_ptr T` emit nothing at all (§14.4, §19.6).

### 11.3 Comparison and `string`

`== !=` on scalars, `typed_ptr`, and enums are the direct opcodes. On a struct,
class, tuple, or `[N]T` whose components are all comparable
(`semantics.md` §3.5), `==` is a call to the synthesized
`fn _Veq_T(a ptr, b ptr) i8` — fields in declaration order, short-circuiting on
the first inequality. This is the same function the map table takes as a callback
(§14.3), so a comparable key type emits it once.

`===` is `eq.ptr` on two slot addresses (§5).

`string` needs `rt` in three places, and this is the only reason it does:

| Source | VIR |
| --- | --- |
| `a == b` | length compare, then `rt_str_cmp` on equal lengths |
| `a < b` and friends | `rt_str_cmp`, then compare its `i32` against zero |
| `a + b` | `rt_alloc(alen + blen, 1)`, null-check → panic, two `memcopy`, build `_Vstr` |

Concatenation allocates and its failure panics, which puts it on the container
tier (`foundation.md` §22.2), not the boundary-tuple tier.

### 11.4 Bounds checks and `panic`

| Vertex | VIR |
| --- | --- |
| `[]T` / `[N]T` subscript out of range | `ult` compare + `br_if` → `trap` |
| a constant subscript provably out of range on a `[N]T` | compile error; no check emitted |
| container allocation failure | null check + `call rt_panic` |
| `panic(msg)` | `call rt_panic, p, len` then `unreachable` |

`panic` satisfying "every path returns" is exactly VIR's `noreturn` +
`unreachable` requirement, so the two rules discharge each other.

### 11.5 The zero-value checks

Three of §9's zero values only behave as specified with a check:

* **Calling a zero `func` value.** The `_Vfn.code` word is null, so every
  indirect call compares it against null and branches to a block calling
  `_Vnullfn`, which panics. One compare and one predictable branch per indirect
  call. The alternative — making the zero value a non-zero `_Vfn` pointing at
  `_Vnullfn` — would mean a zeroed aggregate containing a `func` field is not its
  own zero value, which §9 forbids.
* **Reading through a zero `unique`/`shared` handle.** The handle word is null,
  so a field access through one compares and panics.
* **`upgrade` of a zero `weak`.** No check needed: the increment-if-nonzero loop
  (§13.2) already reports failure through the boundary tuple.

`typed_ptr` is the opposite tier and checks nothing (§14.5).

---

## 12. Closures

### 12.1 Representation

`struct _Vfn(code ptr, env ptr)`. `code` always takes the environment as its
first parameter.

Capturing closures allocate `env` with `rt_alloc` at creation and own it: the
closure's `_Vdrop` drops each captured value, then frees `env`. Captures are
copied in by value at creation (`semantics.md` §7.3), so the copy rules of §7.1
apply per captured binding — a captured `[]T` is a deep copy at the point the
literal is evaluated.

`env` is heap because a closure may outlive its frame
(`func makeAdder(n: int32) -> func(int32) -> int32`). Escape analysis may demote a
non-escaping `env` to an `alloca` — an optimization, not a representation change.

Assigning to a capture is a compile error, so `env` is written once and never
mutated, and the backend may treat it as immutable.

### 12.2 Non-capturing functions as values

A non-capturing function used as a `func` value gets
`_Vthunk_f(env ptr, …)`, which ignores `env` and `tailcall`s the real function.
The `_Vfn` pair is `{addr _Vthunk_f, null}`. The alternative — branching on a
null `env` at every indirect call — costs more, and the null-`code` check of
§11.5 is a different test that a thunk does not remove.

### 12.3 At the foreign boundary

Only a non-capturing function crosses (`abstract_interfaces.md` §6). The value
passed is `addr f` — the real function, not the pair and not the thunk.
Non-capturing-ness is known statically, so there is nothing to strip at runtime.

---

## 13. Heap Handles

### 13.1 `unique T`

One allocation, one pointer word, no header.

| Operation | Lowering |
| --- | --- |
| `unique(e)` | `rt_alloc(sizeof(T), alignof(T))`, null-check → panic, then move `e` in |
| transfer | move the word |
| bare copy | `rt_alloc` + `_Vcopy_T` on the pointee |
| teardown | `_Vdrop_T(p)` then `rt_free(p, alignof(T))` |

No header is why there is no `unique → weak` path: nothing exists to observe.

### 13.2 `shared T`

Per-`T` control block:

```vir
struct _Vsh_Widget(strong i64, weak i64, payload struct Widget)
```

| Operation | VIR |
| --- | --- |
| `shared(e)` | `rt_alloc`, store `strong=1`, `weak=1`, move payload |
| retain (handle copy) | `atomic_add.i64 p, 1, relaxed` |
| release | `atomic_sub.i64 p, 1, acqrel`; if the old value was 1 → drop payload, then release weak |
| `weak(a)` | `atomic_add.i64 wp, 1, relaxed` |
| weak release | `atomic_sub.i64 wp, 1, acqrel`; if the old value was 1 → `rt_free` |
| `upgrade(w)` | increment-if-nonzero loop |
| `drop(var s)` | the release row, emitted at the `drop` call instead of at scope exit |

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

Requiring a back-edge to reach its owner through `upgrade` (`ownership.md` §12)
is what makes this sound: a direct strong back-edge would be a count that never
reaches zero, and reading one from `deinit` would be a count already at zero.

---

## 14. `typed_ptr` and the Allocation Builtins

`typed_ptr T` is one `ptr`. Nothing in this section emits a check, a drop, or a
refcount — that is the tier's entire point (`memory.md` §1).

### 14.1 Operations

| Vertex | VIR |
| --- | --- |
| `&x` (address-of) | the slot address; forces a slot (§5) |
| `&p` (dereference read) | `load.T p` |
| `&p = v` (dereference write) | `store.T p, v` |
| `addr(p)` | the address of `p`'s slot; forces a slot |
| `p.add(n)`, `p.sub(n)` | `index.ptr` with `n * sizeof(T)`, no check |
| `p.at(n)`, `p.setAt(n, v)` | the above, then `load`/`store` |
| `p.diff(q)` | `sub` of two `bitcast` addresses, then `sdiv` by `sizeof(T)` |
| `p == q`, `p < q`, … | `eq.ptr`, `ult`, … — pointers carry no provenance |
| `p == nil` | `eq.ptr p, null` |
| `sizeof(T)`, `alignof(T)` | immediates |
| `reinterpret(T, p)`, `p as typed_ptr U` | nothing |

### 14.2 `new` / `resize` / `delete`

`new` and `resize` are the fallible pair (`memory.md` §11), so both build a
boundary tuple (§8):

```vertex
let buf, err = new[uint8](1024)
```

```vir
  n = mul.i64 1024, 1
  sz = call rt_alloc_zeroed, n, 1
  z = eq.ptr sz, null
  br_if z, oom, ok
ok:
  store.ptr t, sz
  ...                        ; err = ""
oom:
  store.ptr t, null
  ...                        ; err = "out of memory"
```

* `zeroed: true` (the default) picks `rt_alloc_zeroed`; `zeroed: false` picks
  `rt_alloc`.
* `align:` replaces `alignof(T)` in the second argument. A literal that is not a
  power of two is a compile error; a computed one emits a popcount check and
  panics, because that is a bug in the source rather than a state of the machine
  (`memory.md` §11.1).
* **Overflow of `count * sizeof(T)` is an allocation failure**, not a trap: the
  multiply uses `umulo` and branches to the same `oom` block. This is the one
  place a `*` overflow does not reach §11.1's trap, and it is stated in
  `memory.md` §11.1 as a deliberate choice — `count` is caller data off a wire.
* `resize` is `rt_realloc`; on null the input pointer is untouched and still
  valid, which needs no lowering support beyond not clobbering it.
* `delete(p)` is `rt_free(p, alignof(T))`, and `delete(null)` is a no-op inside
  `rt`. It kills nothing and emits no drop.

### 14.3 `copy` / `zero`

`copy(dst, src, n)` is `memmove` — always overlap-safe, with no unsafe variant to
select. `zero(p, count)` is `memset` with a zero byte. Neither checks bounds.

### 14.4 Foreign handles

`abstract` is a `ptr`. `handle as typed_ptr T` on a memory-flat linkage emits
nothing; on an object-graph linkage it is rejected in the front end
(`memory.md` §8) and nothing reaches lowering.

### 14.5 Undefined behavior

Out-of-bounds `.add`, cross-block `.diff`, a stale `delete`, a use after a
successful `resize`, and reading an unzeroed block all lower to plain
`index.ptr`/`load`/`rt_free` with no check, landing in VIR UB categories 1, 2,
and 8. Nothing here narrows them, and nothing here widens them either — the ten
VIR categories are the whole surface.

---

## 15. Vectors

`vector[T, N]` lowers directly to VIR's native `vec[T, N]` register class. Unlike
every other Vertex aggregate it is **not** memory-only — §4.3 does not apply.

### 15.1 Type and tier

| Vertex | VIR |
| --- | --- |
| `vector[T, N]` | `vec[T, N]` |
| lane predicate | `vec[i1, N]` |

Legality is gated by the target's feature tier: `vec[T, N]` is legal only if `N`
fits the tier's native width for `T`. Where the tier is narrower than the source
`N`, the front end splits into `ceil(N / W)` operations over `vec[T, W]` before
VIR sees the wider form, and every opcode below is emitted once per piece. On a
tier with `W = 1`, every vector operation lowers to `N` scalar instructions — the
same shape a hand-written scalar loop produces.

### 15.2 Construction

| Source (`accel.md` §3.2) | VIR |
| --- | --- |
| splat, constant argument | `const.vec[T,N]`, or a `global` plus `load.vec[T,N]` |
| splat, runtime argument | `splat.vec[T,N] v` — opcode missing, §22.11 |
| load, `VectorType(buf, i)` | a compare of `i + N` against the length + `br_if` → `trap`, then `index.ptr` + `load.vec[T,N] p, align E`, `E` being `T`'s element alignment — never the vector's natural alignment |
| lane conversion | the destination-explicit conversion opcode with a `vec[T,N]` destination; float→int traps per lane exactly as its scalar counterpart does |

A constant index provably out of range on a fixed array is a compile-time error
and emits no runtime check.

### 15.3 Store

**There is no vector store.** `accel.md` §3.2 leaves storing a vector back to
memory unspecified — no `.store`, no assignment form, no `copy` overload — so
there is no source construct to lower. When one is specified it is a single
`store.vec[T,N] p, v, align E`, bypassing the `memcopy` path entirely; §22.12
records the gap.

### 15.4 Operations

| Source | VIR |
| --- | --- |
| `+ - * &+ &- &* & \| ^ ~ << >>` | the identical scalar opcode, operands and result typed `vec[T,N]`; the overflow and shift-count checks of §11.1 do **not** apply — lane-wise arithmetic wraps |
| `== != < <= > >=` | the identical comparison opcode, yielding `vec[i1, N]` in place of `i1` |
| `min`/`max` | `min.fN`/`max.fN` for float `T`; `smin`/`smax`/`umin`/`umax` for integer `T` |
| `clamp(v, lo, hi)` | `max` then `min`, both vector forms |
| `blend(m, a, b)` | `select.vec[T,N] m, a, b` — opcode missing, §22.11 |
| `v[k]`, constant `k` | `extract.vec[T,N] v, k` — opcode missing, §22.11 |

Integer `/` and `%` on a vector are rejected in the front end and never reach
this table.

### 15.5 The lane predicate is never in memory

A `vec[i1, N]` value lives only in a register binding, covered by the join
convention like any other named value. It is never the target of
`field.ptr`/`index.ptr`, never a `global` or `const` initializer, never a `struct`
member, and never a channel element — which follows from the source rule that it
has no spelling at all (`accel.md` §3.3). The backend's representation choice — a
mask register, or an all-ones/all-zeros `vec[iN,N]` — is target-dependent codegen
under a fixed opcode meaning, and this document takes no position on it.

### 15.6 Ownership and cost

`vec[T,N]` and `vec[i1,N]` are thin: passed and returned as any scalar is, copied
by register move, torn down by nothing. No `_Vdrop_T` is ever generated for one,
and a struct containing a vector field is not thereby non-trivial.

### 15.7 Boundary rejection

Vectors are rejected in the front end before reaching a `declare` boundary and
before reaching a `gpu` or `npu` signature or body, so nothing in §19 or §20
special-cases them.

---

## 16. Containers

### 16.1 `string`

`{ptr, len}` over UTF-8, no NUL. Literals are a `global` byte array plus a
constant length; `addr .Lstr0` is the pointer.

**A bare copy duplicates the bytes**, matching `semantics.md` §8.5. The
alternative is a refcount header, which puts atomics on a type whose spelling
contains no `shared` — a cost invisible in the source, violating §0.1.

A copy never allocates when the destination is a parameter and the source
outlives the call, but that is a front-end optimization, not a representation
change.

### 16.2 `[]T`

`{ptr, len, cap}`. Growth is amortized doubling through `rt_realloc`; `push` may
reallocate, which is why interior pointers do not exist and slice views are
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

`pop` is a boundary tuple over the same shape, with the empty case writing the
element type's zero (§8, §9).

### 16.3 `map[K]V`

One `ptr` to a type-erased `rt` table. The front end supplies `sizeof(K)`,
`sizeof(V)`, and four function pointers: `_Vhash_K`, `_Veq_K`, `_Vdrop_K`,
`_Vdrop_V` — the last two null when trivial.

Erasure here rather than monomorphization: a hash table is roughly 2 KB of code
with no per-type specialization payoff beyond the comparison, which is already a
pointer.

| Source | VIR |
| --- | --- |
| `m[k]` | `rt_map_get`; null → the zero value plus a non-empty string (§8) |
| `m[k] = v` | `rt_map_set` — an owning position, so the value moves in |
| `m.remove(k)` | `rt_map_erase` |
| `m.length` | `rt_map_len` |
| `for k, v in m`, `.keys()`, `.values()` | the `rt_map_next` cursor (§10.1) |

There is no `nil` anywhere in this table: `nil` belongs to `typed_ptr` and to
nothing else (`semantics.md` §10).

### 16.4 Slice views

`{ptr, len}`, borrowed, never deep-copied, never dropped. Exclusivity forbids
mutating or transferring the viewed buffer while the view is live — enforced in
the front end, invisible in VIR (§22.6).

---

## 17. Generics

Monomorphization, one VIR `fn` per instantiation (§3.1 naming, §3.3 linkage).

* A generic never instantiated emits nothing.
* A method-constraint call lowers to a direct `call` on the concrete type. No
  vtable, no dictionary, no `fnsig` indirection.
* Copy and drop costs are the concrete type's, which is why the cost lint fires
  per instantiation rather than per declaration (`ownership.md` §11).
* `var z: T` is the concrete type's zero (§9).
* Recursive instantiation is bounded by the front end's depth limit before
  lowering runs (`generics.md` §8).

---

## 18. Async

### 18.1 Shape

An `async` function becomes three things:

1. `struct _Vframe_f(state i32, <locals live across a suspend>, <child frames>, result)`
2. `fn _Vresume_f(frame ptr) i32` — one block per resume point, dispatched by a
   `switch` on `state` at entry. Returns `0` = complete, `1` = suspended.
3. a stub `fn f(…)` that initializes the frame.

State lives in the frame in memory, so there are no phi nodes to reconstruct and
no register allocation to restore across a suspend.

### 18.2 `await`

Split the block. Store live locals into the frame, set `state`, return `1`. The
resume block reloads them. Only values live *across* the suspend go in the frame
— the source of `async.md` §7.1's memory-footprint claim, and the reason `await`
forces slots in §5.

Suspension propagates by return value: a `1` from a child resume is stored and
returned, unwinding to the reactor through ordinary returns. There is no
unwinder involved and no stack to switch.

### 18.3 Child frames

`await g()` where `g` is `async` embeds `_Vframe_g` inside `_Vframe_f` and calls
`_Vresume_g` directly. One allocation covers a whole await chain.

**Consequence: recursive `async` is a compile error** — the frame size would not
be computable. Vertex has no boxed-future type and should not grow one; spawn
instead, which allocates a fresh frame (§18.5, §22.7).

### 18.4 `main`

`main` is the reactor root, lowered as an async function whose frame is an
`alloca` in `entry`. VIR gives an `entry` export a bare symbol even in a
namespaced module, and rejects `byval`/`sret` parameters and `noreturn` on it —
all satisfied, since `main` takes nothing and returns nothing
(`semantics.md` §1.4). The `i32` result is the reactor's, and becomes the process
exit code.

```vir
export fn main() i32 entry:
  fr = alloca.ptr 128, align 8      ; sizeof(_Vframe_main)
  store.i32 fr, 0
  rc = call rt_reactor_run, fr, addr _Vresume_main
  return rc
end
```

### 18.5 `async f()` — spawn

Heap-allocate the frame, hand it, `_Vresume_f`, and the result size to
`rt_task_spawn`, which returns a `chan T`. Awaiting that channel is an ordinary
channel receive (§19.3). The transfer marker on a spawned argument
(`async handleClient(var conn)`) is §7.2 — nothing extra is emitted; the point is
what is *not* dropped in the spawning frame.

### 18.6 `async.Readable` / `Writable`

`rt_readable(fd, frame)` / `rt_writable(fd, frame)`, returning
immediately-ready or suspended under §18.2's convention. These two are the entire
reactor seam: a custom reactor (`async.md` §6) reimplements them and nothing
else.

---

## 19. Threads, Channels, `select`

### 19.1 `thread f(x)`

1. `alloca` an argument pack in the *caller's entry block*, move arguments in
2. `rt_chan_new(1, sizeof(T), _Vdrop_T)`
3. `rt_thread_spawn(addr _Vtramp_f, pack)`

`_Vtramp_f(arg ptr) void` unpacks, calls `f`, sends the result, closes the
channel, and frees the pack. A `thread` callee that returns nothing gets a
channel of capacity 1 and element size 0, closed immediately — the handle exists
because the source says a launch evaluates to one (`channels.md` §2.1), and
carries no value.

### 19.2 Channels

One `ptr` to an `rt` channel. The core is type-erased; element size and an
element drop function are supplied at construction.

The drop function is what makes ownership sound across the channel: `send` is an
owning position, so the value moves into the buffer and the receiver inherits
teardown; values still buffered at `rt_chan_drop` are dropped by the channel.
Because every Vertex type has a zero value (`semantics.md` §3.3),
`rt_chan_try_recv` can write a zeroed slot on failure without knowing `T`, and no
element type needs excluding — the lane predicate is not an exception here, since
it cannot be named as an element type at all (§15.5).

Copying a `chan T` handle is a refcount bump (§7.1); `chan[float32](64)` is
`rt_chan_new` with a null-check panic on exhaustion, matching `channels.md` §1.

### 19.3 `.receive()` and friends

| Source | VIR |
| --- | --- |
| `ch.receive()` bare | `rt_chan_recv` — blocks the OS thread |
| `await ch.receive()` | `rt_task_await(ch, out, frame)` — a suspension point, split per §18.2 |
| `ch.send(v)` | `rt_chan_send` — blocks; there is no awaited form |
| `ch.trySend(v)` | `rt_chan_try_send`, status widened to `bool` |
| `ch.tryReceive()` | `rt_chan_try_recv`, status mapped to a boundary tuple (§2.2) |
| `ch.close()` | `rt_chan_close` |

The two receive rows are distinguished by the `await` in the source, never by the
channel — which is exactly what `channels.md` §3.1 promises a reader.

`.receive()` on a closed and drained channel has no specified source behaviour
(`channels.md` §3.1). This document lowers `rt_chan_recv`'s closed status to a
`panic`; see §22.13.

### 19.4 `select`

An `alloca`'d array of `{chan ptr, i32 op}` descriptors, then `rt_select` or
`rt_select_await`, which returns the ready index; a `switch` dispatches to the
case body. A `default:` clause sets the `has_default` flag and takes index `-1`.

Bare and awaited `select` are two different runtime entry points — blocking
versus reactor-registered — which is what the no-mixing rule
(`channels.md` §4.3) buys: the choice is static, so no descriptor carries a mode
and no dispatch inspects one.

`runtime.yield()` (`channels.md` §4.5) is `rt_yield`.

---

## 20. Interop

The `declare` block's build tag and variant tag pick the call shape
(`abstract_interfaces.md` §0, §3.4). In every case the abstract handle is a `ptr`
and no foreign layout is described — a declare block has no fields to lay out
(`abstract_interfaces.md` §3.6).

### 20.1 Flat C (`linux`, `windows`, non-framework `darwin`)

A direct `extern` group and a direct `call`. `mut T` scalar out-params are
already pointers (§6), so `mut int32` *is* `int32*` with no adaptation, and a
`[]T` argument passes its `_Vslice` pointer with the length dropped.

### 20.2 Foreign variadics

Declared with `...` in the VIR `fnsig`; VIR handles varargs at the call site.
Vertex never emits `va_start`/`va_arg`/`va_end`, because it cannot define a
C-variadic function — a Vertex variadic parameter is an ordinary iterable
(`foundation.md` §5), lowered to a stack `array[T, N]` plus a `_Vslice` over it,
`N` fixed per call site.

### 20.3 Strings at the boundary

Vertex strings have no NUL. Each `string` argument marshals:

```vir
  cs = call rt_cstr_new, sp, slen
  call SDL_CreateWindow, cs, ...
  call rt_cstr_free, cs
```

The free is emitted on every exit edge of the call's statement, like a `defer`.
A runtime call rather than a dynamically sized `alloca`, because VIR's `alloca`
is a fixed frame slot and the case is already paying a foreign call (§22.8).

### 20.4 Objective-C (`declare framework`, `darwin`)

`objc_msgSend` with a cached selector, and `link framework "AppKit"` in the
module's link section. Selectors cannot be `global` initializers — VIR forbids
calls in initializers — so each is a lazily filled `global`:

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

### 20.5 C++ (`cxx`, Itanium; `windows` raw vtable; `com`)

Non-virtual member calls use the mangled symbol in the `extern` group, `this`
first. Virtual and COM calls load the vptr at offset 0, index it, and
`call.<fnsig>` against a declared signature.

**Exceptions cannot be caught.** VIR has no unwinder and Vertex has no `catch`. A
C++ exception escaping into Vertex is UB, and every foreign declaration is
effectively `nounwind` by fiat. `"no-exceptions"` is therefore the only
configuration with defined behavior across the boundary (§22.9).

### 20.6 `abstract` → `typed_ptr T`

Memory-flat imports: a no-op reinterpretation, since the handle already is an
address. Object-graph imports (JS, Darwin frameworks) are rejected in the front
end (`memory.md` §8); nothing reaches lowering.

---

## 21. Device Code and Tests

### 21.1 `gpu` and `npu` do not lower to VIR

VIR is CPU-only by charter; both markers target a separate IR, **GVIR**,
specified in `gvir.md`. Everything about device bodies — their restricted
constructs, their type systems, their launch shapes, and their runtime entry
points — belongs to that document.

The only obligation this document carries is the exclusion itself: a device body
never reaches any table above, and the front end rejects `vector[T, N]` in a
device signature or body (§15.7) before lowering begins. The host↔tensor
conversion at a launch site (`accel.md` §2.1) is the launch's own business and
leaves nothing behind on the CPU side but the argument marshalling GVIR
specifies.

### 21.2 Tests

A `build test` file compiles to its own module with an `entry`.

| Form | Lowering |
| --- | --- |
| `test -> Expected(T, "…")` | exported `fn`; the runner compares emitted formatting to the literal |
| `test` with no expectation | exported `fn`; passes if it returns |
| `test -> Expected(error)` | **not lowered** — a compile-time assertion; a body that compiles is a test failure |
| `test -> Expected(error, "…")` | not lowered; additionally matches the diagnostic text |

`Expected(error)` never producing code is why `diagnostics.md` is a real
dependency: the assertion is on diagnostic text, which lives nowhere in this
pipeline.

---

## 22. Open Items

Changes or ratifications needed elsewhere. Everything above assumes all of it.

**22.1 Reserve the `_V` prefix.** `semantics.md` §2.3 lists what may not be
declared; an identifier beginning `_V` must join it. One line.

**22.2 Tuple returns are `sret`, always.** Register-pair returns are a backend
promotion on a non-`export` function, never a VIR guarantee (§8).

**22.3 The rt allocator must recover block size from an address.** `delete[T](p)`
carries no count (`memory.md` §11.2), so a sized-deallocation ABI is not
implementable from the source language. Either `rt` uses size-class segments with
address-recoverable sizes — the assumption §2.2 makes — or `memory.md` grows a
counted `delete`, which would be a worse language for the sake of a cheaper
allocator. **Recommend the former.**

**22.4 Monomorphized instances duplicate across modules.** No `linkonce`/COMDAT
in VIR. **Recommend accepting** — dedup is a size optimization; VIR's
flat-namespace guarantee is worth more.

**22.5 `js` and `wasm` cannot lower to VIR** — VIR admits real silicon only.
**Recommend** a parallel `wasm-lowering.md`. This document is native-only until
one exists.

**22.6 Exclusivity is not transmitted to VIR.** Shared parameters, `mut`
parameters, and slice borrows all pass as a bare `ptr`; the front end proves
non-aliasing and discards the proof. **Proposal:** add `noalias` and `readonly`
parameter attributes to VIR. Highest-value item on this list.

**22.7 Recursive `async` must be a compile error** (§18.3). A new front-end rule;
the diagnostic should point at spawning.

**22.8 Three VIR spellings need pinning** — the `alloca` operand form, `index.ptr`
scaling, and the `cmpxchg` result shape (§0.1). Also whether `alloca` may be
dynamically sized, which would remove the `rt_cstr_new` round trip (§20.3).

**22.9 Reconsider `exceptions on` as the C++ default.**
`abstract_interfaces.md` §3.3 defaults `darwin` and `linux` nested classes to
Itanium C++ with exceptions on, and an escaping exception is UB with no unwinder
to make it otherwise. **Recommend** defaulting to no-exceptions.

**22.10 `%` on floats has no opcode.** VIR gives `srem`/`urem` and no `frem`.
Either `semantics.md` §5.1 restricts `%` to integer types — the reading this
document assumes — or VIR grows `frem`. **Recommend the former.**

**22.11 Three vector opcodes VIR does not name.** Arithmetic, comparison, and
min/max reuse scalar opcodes (§15.4); these three have no scalar analog:

* `splat.vec[T,N] v` — broadcast a runtime scalar into every lane (constants are
  already covered by `const.vec[T,N]`).
* `extract.vec[T,N] v, k` — read lane `k`, `k` a compile-time immediate.
* `select.vec[T,N] m, a, b` — per-lane select keyed by a `vec[i1,N]` mask; the
  entire lowering of `blend`, and not composable from bitwise ops without an
  implicit narrowing of the predicate that no other rule permits.

All three are single-instruction-shaped and introduce no new register class,
memory form, or runtime question. **Recommend adding all three** — without them,
§15.2 and §15.4 name opcodes that do not exist.

**22.12 Vectors cannot be stored.** `accel.md` §3.2 leaves the store form
unspecified, so §15.3 has nothing to lower and a `vector` can be loaded, computed
on, and read a lane at a time, but never written back in one instruction.
**Recommend** specifying a store form; the lowering is one `store.vec` and is
already described.

**22.13 A receive on a closed, drained channel is unspecified.**
`channels.md` §3.1 leaves it open and every drain loop in the corpus avoids it by
using `.tryReceive()`. This document lowers it to a panic, which is a choice made
here for want of one made there. **Recommend** stating it in `channels.md` —
panic is the honest reading, since the alternative is handing back a zero value
that the caller has no way to distinguish from a real one.