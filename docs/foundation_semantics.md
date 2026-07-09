# Vertex Language Reference: Foundation & Data Layout

## Specification 2.7 — Semantics & Rationale

Companion to `foundation.md`. This document defines what Vertex syntax *compiles to*: sizes, layouts, calling conventions, lowering, and the runtime cost model. It is strictly aligned with Ownership & Access (Spec 2.5) and leans on its guarantees — in particular Move Invalidation (2.5 §3.5) and Rule 0 — as load-bearing walls.

**Design principles.**

1. **Pay for what you spell.** Every construct has one stated price, and the expensive ones are the ones that require explicit ink (`clone`, `shared`, `weak.upgrade()`). Anything silent is free or near-free.
2. **Static proof over runtime check.** Where the compiler can prove a property (liveness, bounds, exhaustiveness), no code is emitted for it. Runtime checks exist only where proof is impossible, and each one is documented below.
3. **The Extent Rule.** A handle is **fat** exactly when the value's extent (length/size) is not part of its static type. There are no thin pointers with programmer-tracked lengths — that pairing is the classic desynchronization bug, so it is unrepresentable.
4. **Compiler-owned layout.** Unless a type opts into a fixed layout (explicit-discriminant enums, §6.4), the compiler owns field order, padding, and niche reclamation. Source order is documentation, not ABI.
5. **Trivial moves, always.** Every move is a flat `memcpy` of the handle words. This is only possible because Move Invalidation statically kills the source name — there is no moved-from husk, hence no move constructors, no null states, no "valid but unspecified." Any layout decision that would break trivial movability is rejected (see: no SSO, §9).
6. **One way per meaning.** No two constructs in the grammar are interchangeable spellings of the same operation. Where a convenience form was considered and cut (`..=`, range methods, three-clause loops), the rationale is recorded at the section that absorbed its use case.

---

## 0. The ABI Rule

Any value type ≤ 2 machine words — structs, tuples, fixed arrays, enum payloads, fat handles, ranges — passes and returns **in registers**. Anything larger passes by hidden reference and returns via an `sret` out-pointer.

This single rule, combined with the Extent Rule, is why the fat-handle shapes below were chosen: a Shared-Access slice (`{ptr, len}`) and a range (`{start, end}`) are exactly two words each and ride in registers; the owning triple (`{ptr, len, cap}`) is three and doesn't — which is fine, because owners move rarely and views pass constantly.

---

## 1. Bindings: `let` vs `var`

Mutability is a property of the **binding**, not the type. There is no `const int32`.

* **`var`** — permits reassignment, field mutation, and granting Exclusive Access (`mut`).
* **`let`** — freezes the binding. Reassignment, field mutation, and `mut` grants are compile errors.
* **Consumption** — you *can* move out of a `let`. A move doesn't mutate the value; it relocates ownership and kills the binding. Immutability constrains what the value becomes, not who owns it.

> **Zero runtime cost:** `let` and `var` share an identical representation. The distinction exists only in the checker.

**Why binding-level and not type-level:** type-level constness bifurcates every API (`T` vs `const T`) and infects generics. Vertex already has an access ladder in parameter position (bare / `mut` / `own`); duplicating it in the type grammar would say the same thing twice — a violation of principle 6.

---

## 2. Numerics

### 2.1 Default types

An unsuffixed integer literal is `int` (machine word); an unsuffixed float literal is `float64`. Literals are **polymorphic until bound**: `let b: int8 = 127` type-checks the literal against `int8` directly — no implicit runtime conversion, and `let b: int8 = 128` is a compile error, not a wrap.

### 2.2 Overflow

* **Plain operators (`+ - *`)** trap on overflow in checked builds and produce an unspecified *value* (never undefined *behavior*) in release builds — the result bit pattern is arbitrary, but no memory unsafety can follow from it.
* **Overflow operators (`&+ &- &*`)** wrap, in every build mode, guaranteed. They are the spelling for hashes, PRNGs, and ring counters — cases where wrapping is the *algorithm*, not an accident.

Marking principle: silent code is safe code; intentional wrapping is loud.

### 2.3 Conversion: `T(x)` vs `as`

These are **not** synonyms — each has a distinct contract (principle 6).

| Form | Contract | Cost |
| --- | --- | --- |
| `int8(x)` | **Checked, value-preserving.** Traps if `x` doesn't fit. `int(3.99)` traps — fractional loss is not value-preserving. | branch + convert |
| `x as int8` | **Explicit, lossy, never traps.** Integers truncate bits; floats truncate toward zero; float→int out of range saturates. | convert only |

`T(x)` asserts "this fits"; `as` declares "I accept the lossy mapping." Widening conversions (`int32 as int64`) are always value-preserving, so `as` is the idiomatic spelling there and compiles to a single sign/zero-extend. Enum-to-integer (`Status.Active as int32`, §6.4) is a zero-cost reinterpretation — no code at all.

---

## 3. Memory Layout Cheat Sheet

| Type | Extent in type? | Handle shape | Notes |
| --- | --- | --- | --- |
| `int*`, `uint*`, `float*`, `bool`, `char` | — | value | `bool` is 1 byte holding 0/1 (niche-rich); `char` is a 4-byte Unicode scalar. |
| `range<T>` | No | pair `{start, end}` | Two words, registers. §13. |
| `[T; N]` | Yes (`N`) | thin value | Inline (stack/registers/parent). Bounds checks against constant `N`, usually folded. |
| `[T]` owned | No | fat triple `{ptr, len, cap}` | Move = 3-word copy. `[]` allocates nothing. |
| `[T]` view (shared access / slice) | No | fat pair `{ptr, len}` | `cap` is owner-only; readers can't push. §7.3. |
| `string` | No | fat triple | Byte-identical to `[uint8]` + UTF-8 invariant. **No SSO** — §9. |
| `map<K,V>` | No | 1 word | Heap SwissTable, per-process seeded hash (HashDoS resistance). `{}` allocates nothing. |
| `T?` | — | `T` or `T` + tag | Niche-filled when possible, §6.2. |
| class | — | 1 word, never null | §5. |
| `shared<T>` | — | 1 word | Object and control block co-allocated. |
| `weak<T>` | — | 1 word | Points at the control block only. |
| `func(...)` non-capturing | — | 1 word | Code address. |
| capturing closure | No (env varies) | fat pair `{code, env}` | §10. |

---

## 4. Structs & Tuples (Value Types)

* **Layout:** inline, field-by-field. The compiler reorders fields to minimize padding (principle 4).
* **Tuples are anonymous structs.** `(int32, string)` and a two-field struct lower identically. Named tuple fields exist only in the checker — positional and named access compile to the same offset load. Destructuring is sugar for field reads (or field *moves*, if the tuple is consumed).
* **Cost:** no heap, no header. Small structs are routinely dissolved into registers by SROA and never exist in memory at all.
* **Copy vs. move:** structs of only trivially-copyable fields copy on assignment; structs containing owning handles (dynamic arrays, strings, classes) move, with Move Invalidation applying as usual. Copy-or-move is a static property, never a runtime question.

---

## 5. Classes (Reference Types)

* **Layout:** one machine word — a never-null pointer to a heap allocation.
* **Ownership:** pure RAII; a class binding *is* a zero-cost `unique_ptr`. `init` at construction, `deinit` exactly once at scope end of the final owner.
* **No null branch in deinit:** use-after-move is a compile error, so the compiler knows statically which binding dies owning the object. The moved-from case doesn't exist at runtime.
* **`shared<T>`:** one word to a co-allocated `{object, control block}`. Shared-Access passing and moves do **not** touch the counts — count traffic occurs only on explicit duplication and on destruction of a duplicate. Identity operators (`===`, `!==`) compare the handle words.

---

## 6. Enums & Optionals

### 6.1 Lowering

Tagged unions: payload storage sized to the largest variant, plus a discriminant. The compiler shrinks aggressively, in order of preference: (1) **elide** the tag via a payload niche; (2) **hide** it in alignment padding; (3) **shrink** it to the smallest fitting integer. Unit-variant enums are just the tag — typically 1 byte.

### 6.2 Optionals are niche-filled enums

`T?` is `enum { Some(T), None }` given the full pipeline:

* `T` has a niche (class handle → null; `bool` → 2–255; `char` → invalid scalar range): **`T?` is the same size as `T`**, `nil` is the niche pattern, `if let` is a compare-against-niche.
* `T` has no niche (`int32` uses all 2³² patterns): tag byte + payload, padded — 8 bytes for `int32?`.

### 6.3 `switch` lowering

* **Integer/enum scrutinee:** jump table when dense, compare chain when sparse.
* **Range case (`case 0..100:`):** two compares (`>= start && < end`); adjacent range cases share bounds. A range in case position is the same `{start, end}` value as everywhere else — the compiler simply constant-folds it into the compare chain. Overlapping ranges are a compile error; first-match would be order-dependent, and order-dependent case lists are a silent-bug factory.
* **String scrutinee:** length filter, then `memcmp` chain (perfect hash for large sets). Never a runtime hash-map lookup.
* **Payload binding (`case .Circle(r)`):** a field load after the tag test — binding names cost nothing.
* **Exhaustiveness** is static; a fully-covered enum switch emits no default trap.
* **`fallthrough`** is a static jump to the next body, not a re-test.

### 6.4 Explicit discriminants

`enum Status : int32` **opts out of compiler-owned layout**: guaranteed to be exactly that integer type, payload-free, declared values. This is the FFI/wire-format escape hatch and what makes `s as int32` free. The price: no payload variants, no niche games. Integer→enum goes through a user-written checked constructor returning `Status?` — the compiler won't invent a validity check, because only you know the valid set.

---

## 7. Arrays

### 7.1 Fixed `[T; N]`

Inline storage, `N` in the type. Constant indices fold the bounds check at compile time; runtime indices check against constant `N` — one compare against an immediate, usually eliminated by range analysis (`for i in 0..N` proves every access).

### 7.2 Dynamic `[T]`

The owning triple. `push` is amortized O(1) with geometric growth (×2 below 1024 elements, ×1.5 above); `pop` moves the last element out — returns `T`, ownership included — and never shrinks capacity implicitly. `[i]` traps out-of-range; the check is elided wherever the index is provably in range, and the trap is a statically-known cold path.

**Reallocation and anchors:** an array of anchored children reallocating is an *internal move that preserves the owner* (2.5 §12.5) — legal; the tree moved as a tree.

### 7.3 Views: bare parameters and slices are the same thing

Passing a `[T]` or `[T; N]` to a bare parameter, and slicing with `arr[a..b]`, both produce the **view**: `{ptr, len}`, two words, registers. The callee/holder cannot push (no `cap`) and cannot store it — **a view is an access grant, and Rule 0 applies in full**: not storable in a field, not returnable, not capturable by a closure. This is not a new rule; it's the observation that a slice *is* Shared Access with a narrower extent, so it inherits Shared Access's entire contract, including its zero cost.

Slicing bounds-checks once at construction (`a <= b <= len`, traps otherwise); accesses through the view then check against the view's own `len`. `arr[a..b]` where `a == b` is a valid empty view.

**Why slices aren't owning values:** a storable slice is a stored pathway into memory owned elsewhere — the exact liveness problem Spec 2.5 exists to delete. Languages that allow stored slices pay for them with lifetime annotations (Rust) or GC (Go). Vertex's answer is the same as its answer for `mut`: the pathway dies with the call, so the question never arises. Code that needs to *keep* a sub-range keeps `(start, end)` indices or `clone()`s the sub-range — both spellings make the cost and the ownership visible.

---

## 8. Maps

`map<K,V>` is one word to a heap SwissTable: open addressing, SIMD group probing, per-process hash seed. `m[k] = nil` is deletion (hence `map<K, V?>` is disallowed — the sentinel must be unambiguous). Reads return `V?`, niche-packed per §6.2. Iteration order is unspecified *and seeded* — programs cannot accidentally depend on it, and the seeding turns "accidentally" into "observably broken on the next run," which is the kindest possible failure mode.

---

## 9. Strings & Chars

* **`string`** is UTF-8 bytes behind a fat triple, byte-identical in layout to `[uint8]`. The type boundary carries one invariant — well-formed UTF-8 — enforced where bytes become strings, and nowhere else.
* **No SSO.** Small String Optimization makes moves non-trivial (interior pointers into the moved-from handle) and adds a branch to every access. Principle 5 wins; SSO is rejected.
* **`char`** is a 4-byte Unicode scalar. `'A'` is a `char`; `"A"` is a one-byte string. Iterating a `string` yields `char` by UTF-8 decode (§14.4); byte access goes through `.bytes()`, so "bytes or characters?" is answered by the type at every site.
* Multiline backtick literals are a lexer feature only — same runtime type.

---

## 10. Functions & Closures

The Extent Rule, applied to code:

1. **Non-capturing `func`** — one word, a code address. A non-capturing anonymous function is identical to a named one.
2. **Capturing closure** — fat pair `{code_ptr, env_ptr}`. Captures are **by value at creation**: the environment is a compiler-generated struct of copies. This is why mutating a captured `var` is a compile error — you'd be mutating a copy, and Vertex refuses to compile that as if it meant something.
3. **Writeback** goes through the front door: a `mut` parameter on the closure's own signature, passed at the call site. No hidden boxes, no capture-by-reference — Rule 0 forbids storing access grants, and closures get no exemption (2.5 §12.8 is the same rule from the other side).

**Stack promotion:** a closure passed by bare parameter cannot outlive the call — Rule 0 guarantees it — so its environment is allocated **on the caller's stack**. Heap allocation happens only when a closure is *stored*, which is exactly when it must survive. The ownership rules aren't just safety here; they *are* the escape analysis, with a proof instead of a heuristic.

---

## 11. Error Handling

`(T, error-ish)` tuples, by convention `(T, string)` or `(T, bool)`.

* **Layout:** tuples are anonymous structs (§4); small ones return in registers. `((), bool)` is one byte.
* **`?` operator:** pure sugar — destructure, test the error slot against its empty value, early-return propagating on failure. A compare and a conditional return. Nothing else.
* **`if let` / `else -> err`:** the same destructure with both arms in source order.
* **No unwinding.** No unwind tables, landing pads, or invisible control flow. Every function's exits are visible in its source. `defer` (§12) is the cleanup mechanism, and it composes with early returns because both are ordinary control flow.

The trade is explicit: fallibility costs a visible word in the return type instead of an invisible mechanism in the binary.

---

## 12. Defer

`defer` bodies execute at scope exit, LIFO, on **every** exit path — fall-through, `return`, `?` propagation, `break`/`continue` (including labeled forms, §14.6) leaving the scope.

* **Lowering:** the compiler duplicates or jump-threads the deferred body into each exit edge — static code, no runtime list, no allocation.
* Operands are captured by the usual rules where the `defer` statement *executes*; the body is evaluated when it *fires*.
* Ordering interlocks with RAII: deferred statements run before `deinit` of the scope's locals, in reverse declaration order — your cleanup runs while the values it mentions are still whole.

---

## 13. Ranges

`a..b` constructs a `range<T>`: two words, `{start, end}`, always **half-open** — `a..b` contains `a` and excludes `b`, empty when `a >= b`. It is an ordinary value (ABI Rule: registers) legal in every value position, and three positions give it special lowering:

* **loop position** — §14.1
* **bracket position** — a view, §7.3
* **case position** — two compares, §6.3

**Why exactly one range operator.** An inclusive form (`..=`) was considered and cut under principle 6: it is interchangeable with `a..b+1` in every case except one — covering the full domain of an integer type, where `end + 1` is unrepresentable (`0..=uint8.max`). That single case is served by iterating a wider type and casting (`for i in 0..256 { let b = i as uint8 }`), a documented wart accepted in exchange for never having two spellings of the same interval. Half-open is the default because it composes: `a..b` and `b..c` tile without overlap, `len` is directly a valid bound, and empty is representable without a special case — the same reasons indexing has been half-open since Dijkstra's memo.

**Why no range methods.** `.reversed()` and `.by(step)` were considered and cut: everything they compute is a three-line `while` loop, so they'd be a second spelling of an existing construct — and unlike `..=`, there is no case they alone can express. Stepping and reversal are *manual index arithmetic*, and `while` is the language's honest spelling for manual index arithmetic. This is the deliberate anti-Rust position: no iterator-adapter zoo, because every adapter is a grammar-adjacent surface that must be learned, and the loop it replaces was already three lines.

**Why an operator and not `range(a, b)`.** Bracket and case position. `buf[range(2,5)]` and `case range(0,100):` are unwritable without either making a function call a pattern (grammar damage) or quarantining a second range notation inside brackets, which is Go's `[a:b]` fragmentation — three disconnected range-ish mechanisms where one value suffices. The operator earns its precedence-table row by appearing in positions a call can't.

---

## 14. Loops

There are two loop constructs, with disjoint jobs (principle 6):

* **`for`** consumes an iterable value. It owns no arithmetic.
* **`while`** runs manual state machines: stepping, reversal, sentinel-driven loops, anything with a hand-managed counter.

There is no three-clause C loop. It is a manual state machine wearing `for`'s keyword — the counter, condition, and step are hand-managed but visually disguised as structured iteration, which is exactly the combination that breeds off-by-ones. Vertex makes the manual case *look* manual: it's a `while`.

### 14.1 Range iteration

```vertex
for i in 0..n { }
```

Lowers to the obvious counted loop — induction variable, compare, increment. No iterator object, no calls, no protocol dispatch. The zero-cost claim, concretely: this and the equivalent hand-written `while` compile to identical machine code. The range is constant-folded out of existence; `{start, end}` never materializes in memory when the bounds are locally known.

### 14.2 Array iteration and the access ladder

The loop head carries the same three-position ladder as parameter passing (2.5 §4), applied per element:

```vertex
for n in nums { }            // shared access — n is a read of the element in place
for n in mut nums { }        // exclusive access — writes go to the element in place
for f in own frames { }      // move — each element moves out; container dies
```

* **Bare:** lowers to an index loop over the `{ptr, len}` view, bounds check hoisted (the loop bound *is* `len`). The element is read in place — no per-element copy for large `T`.
* **`mut`:** same loop; the container is exclusively accessed for the loop's duration, checked by the ordinary §9 (2.5) rules — the loop body reading the container by another name is a compile error. `push` inside the body is likewise excluded (it's a second exclusive access, and reallocation would invalidate the live pathway — the classic iterator-invalidation bug, made unrepresentable by the exclusivity check rather than by a runtime version counter).
* **`own`:** consuming iteration. Each element moves out (header copy, §11 of 2.5); after the loop the container's name is statically dead — ordinary Move Invalidation, no new mechanism. The container's storage is freed at loop end; element `deinit`s ran in the body iff the body didn't move them onward.

**Index pairing:**

```vertex
for i, n in nums { }
```

`i` is the induction variable the lowering already had — exposing it costs zero. This is the one special power of the loop head, adopted from Go, where it proved to cover indexing needs without an `enumerate` wrapper.

### 14.3 Map iteration

```vertex
for k, v in config { }
```

Lowers to a SwissTable group walk — control-byte scan, skip empties/tombstones. `k` and `v` are shared-access reads in place. Order is unspecified and seeded (§8). Mutating the map during iteration is excluded by the same exclusivity reasoning as §14.2 — the loop holds a live pathway; `config[k] = x` in the body needs a second, overlapping one. `.keys()` / `.values()` are the same walk yielding one slot.

### 14.4 String iteration

```vertex
for c in s { }               // char — inline UTF-8 decode, no calls
for b in s.bytes() { }       // uint8 — the raw view, memcpy speed
```

The decode loop is branchy but allocation-free and call-free; ASCII-heavy text runs at one compare per byte. The two forms are not interchangeable spellings (principle 6): they iterate different sequences with different lengths.

### 14.5 `while let`

```vertex
while let job = queue.pop() { }
```

The §6.2 optional test applied as a loop condition — compare-against-niche, branch. It is to `while` what `if let` is to `if`: the same binding form, not a new one.

### 14.6 Labeled break/continue

```vertex
outer: for i in 0..n {
    for j in 0..m {
        if hit(i, j) { break outer }
    }
}
```

Static jumps to statically-known targets — zero cost, no unwinding. `defer`s in scopes being exited fire in LIFO order on the way out (§12). Labels exist because their absence breeds the flag-variable workaround (`var found = false` threaded through two loop levels), which is a manual state machine smuggled into structured code — the same disease the three-clause loop was cut for.

---

## 15. Compile-Time Structure

`package`, `build`, and `import` exist only at compile time — no runtime registry, no initializer-ordering problem (there are no mutable globals to initialize; 2.5 Known Obligations §5).

**Testing (`build test`)** lowers each `test` function to: run body → format the return with the table's `printf` spec → string-compare against the `Expected` literal. `Expected(error)` tests invert the compiler: the unit is compiled in isolation and the test passes iff compilation fails (with the matching message, if given). Test machinery contributes zero bytes to non-test builds.

---

## 16. The Cost Table

Everything in the language, one column of prices (extends 2.5 §11.2):

```
struct copy              O(fields)   usually registers
move (any type)          O(1)        handle memcpy, source statically dead
clone                    O(data)     the only deep copy, always spelled
bare parameter / slice   free        {ptr,len} view, Rule 0 scoped
mut parameter            free        same passing, exclusivity checked statically
own parameter            ~free       handle copy
range value              free        {start,end}, registers, folded in loops
for over range           free        identical codegen to hand-written while
for i,v / for k,v        free        exposes the induction variable / slot walk
for .. own               O(1)/elem   header moves, container statically dead
b.parent (unowned)       free        one load, zero checks
w.upgrade() (weak)       runtime     branch + count traffic
shared<T> duplicate      runtime     count increment
array push               O(1) am.    geometric growth
array index              O(1)        check elided when provable, else 1 cmp
slice construction       O(1)        one bounds check at creation
map index                O(1) exp.   SwissTable probe
switch, range case       O(1)        two compares, folded into the chain
?  propagation           O(1)        cmp + cond return, no unwinding
defer / labeled break    free        statically threaded exit edges
closure, passed bare     free        stack environment
closure, stored          O(env)      one heap allocation at creation
```

The pattern the table exists to show: **every O(data) or runtime-checked row has mandatory ink at the use site**, and every silent row is O(1) or free. Reading Vertex source *is* reading its profile.

---

## Known Obligations

1. **View escape analysis** (§7.3) — slices inherit Rule 0; the checker must treat `arr[a..b]` uniformly with bare-parameter views in the same dataflow pass.
2. **Loop-body exclusivity** (§14.2, §14.3) — `for _ in mut xs` holds exclusive access for the whole loop; the §9 (2.5) check must extend across the body, not just the header.
3. **Consuming iteration + early exit** (§14.2) — `break` out of `for f in own frames` leaves unmoved elements; decide: remainder `deinit`s at loop exit (proposed) vs. container survives partially-moved (rejected — partial moves reintroduce the husk).
4. **Full-domain iteration wart** (§13) — `0..=T.max` has no direct spelling; confirm the widen-and-cast idiom is acceptable in the stdlib's own code before freezing.
5. **Overflow in release builds** (§2.2) — "unspecified value, never UB" vs. trap-everywhere is still open; the choice affects whether `&+` is an optimization hint or purely semantic.