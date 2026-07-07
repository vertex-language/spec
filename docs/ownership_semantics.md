# Vertex Language Reference: Ownership Semantics

## Specification 2.2 — Semantics & Rationale

Companion to `ownership.md`, same section numbers. Includes the same code as `ownership.md` plus the reasoning behind each form.

**Lineage.** The foundations here are inherited from C++: `unique_ptr` gives single-owner, move-only semantics at zero runtime cost; `shared_ptr` gives refcounted multi-ownership for the graph/cycle cases that need it; `std::move` marks a transfer of ownership; and RAII (classes with deterministic constructor/destructor pairs) gives scope-based cleanup with no manual bookkeeping. This system keeps all four ideas, but takes the *marking* of `mut` from Rust (`&mut T`) rather than leaving mutation silent the way C++ does — `mut` is flagged both in the signature and at the call site.

**Design principle:** mark the dangerous case, default the safe one. A borrow can't destroy anything, so it's silent. A move ends a variable's life, so it's loud. Mutation sits in between — flagged, but not fatal — so it's marked at both ends. This is deliberately inverted from Rust's call sites, where borrows are marked (`&x`) and the destructive move is silent (`f(x)`). Here, silence always means safe.

**Spelling rule.** The convention always lives in type position — name on the left of the colon, contract on the right: `x: T` reads, `x: mut T` mutates, `x: T&` consumes. One slot, three values. (Rust splits these: its mutable borrow rides in the type (`&mut T`), but `mut` before a parameter name means something unrelated — an owned, locally mutable binding. Vertex keeps the name-prefix slot unused so the two ideas can never collide.)

---

## 1. Borrowing (default)

```vertex
func inspect(w: Widget) {
    print(w.id)
}

let w = Widget(1)
inspect(w)
inspect(w)
```

A bare name is a safe, read-only borrow — like passing `const T&` in C++, but with no sigil needed, since this is the overwhelmingly common case. Calling `inspect(w)` twice in a row is fine precisely because a borrow consumes nothing.

This silence is trustworthy because of Invariant A: a borrowed parameter can be passed further down but never returned, stored, or outlived. That's what lets the language skip lifetime annotations entirely — a borrow's scope is always exactly the call it's part of.

---

## 2. Mutation — `mut`

### 2.1 Declaration

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}
```

Mutation is a step up from a read but doesn't end the variable's life like a move does, so it gets its own sigil — the Rust-style `mut`, rather than C++'s silent `T&`. Per the spelling rule, it sits in type position: `mut Widget` is the contract, `w` is just the name.

### 2.2 Call Site

```vertex
var w = Widget(1)
rename(mut w, "draft")
```

`mut` is echoed at the call site, not just the signature — going further than Rust's `&mut x`, which requires the same discipline, but matching its spirit. C++ leaves mutation silent at the call site entirely (`T&` looks identical to a read); here the call site alone tells the whole story.

### 2.3 Mut Parameters (functions, non-methods)

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(mut count)
```

Same rule for scalars as for structs — the sigil marks the *convention*, not the size or shape of the value.

### 2.4 Mut Receivers

```vertex
func (w: mut Widget) rename(tag: string) {
    w.log.push(tag)
}

w.rename("draft")
```

Receivers follow the same convention as ordinary parameters. The one asymmetry: the call site (`w.rename(...)`) carries no visible `mut`, since method syntax has no slot for it. The contract lives entirely in the declaration.

---

## 3. Consume — postfix `&`

### 3.1 Declaration

```vertex
func archive(w: Widget&) {
    storage.push(w&)
}
```

This is `std::move`'s territory — the one place ownership actually transfers away from the caller — so it gets the loudest marker in the grammar. `w` is consumed a second time inside `archive`'s own body, when pushed into `storage`: consume is a general operation on any owned value, not a one-shot event tied to the call boundary, and each further handoff needs its own `&`.

### 3.2 Call Site

```vertex
var w = Widget(1)
archive(w&)
```

Consume is postfix (`w&`), not prefix like `mut` — reading left to right, you see the value first and its fate second, mirroring that `w` stays usable right up to the instant of handoff.

### 3.3 Move Into a Binding

```vertex
var w = Widget(1)
var final = w&
```

Same as `auto b = std::move(a)` in C++, but spelled at the source — assigning into a new variable is exactly as destructive to the source as passing it to a consume parameter, so it takes the identical sigil.

### 3.4 Chained Moves

```vertex
var w = Widget(1)
var a = w&
var b = a&

archive(b&)
```

Each hop re-spells `&`, so the current owner is always the name without a live successor — the custody trail is fully visible on the page.

### 3.5 Use-After-Move (compile error)

```vertex
var w = Widget(1)
var final = w&
inspect(w)          // error: use of moved value `w`
```

C++ permits this and calls it undefined behavior after a `std::move`. Rust catches it, but only announces it via the error at the use site — nothing marks the move itself as dangerous. Making `&` *mandatory* rather than optional closes that gap: a consume site without it is a compile error, never a silent copy.

---

## 4. Conventions Summary (grammar forms)

```vertex
func f1(x: T)          // read — bare, no sigil
func f2(x: mut T)       // mutate — sigil in signature
func f3(x: T&)          // consume — sigil in signature

f1(x)                  // read — bare, no sigil
f2(mut x)               // mutate — sigil at call site
f3(x&)                  // consume — sigil at call site
```

| convention        | C++ (spelling)   | Rust        | Vertex        |
|-------------------|------------------|-------------|------------|
| read (default)    | `const T&`       | `&T`        | bare       |
| mutate in place   | `T&`             | `&mut T`    | `mut`      |
| consume           | `T` / `std::move`| `T`         | `T&`       |
| move at call site | `std::move(x)`   | *(silent)*  | `x&` REQUIRED |
| mut at call site  | *(silent)*       | `&mut x`    | `mut x` REQUIRED |

In ordinary code reads vastly outnumber moves, so the sigil count stays low overall — and every `&` that appears is guaranteed to be meaningful. Note the column discipline in the declaration forms: the contract is always the thing after the colon — `T`, `mut T`, `T&` — never split between name-prefix and type-suffix positions.

---

## 5. Method Receivers

```vertex
func (p: Point) describe() {
    let n = p.x
}

func (p: mut Point) reset() {
    p.x = 0
    p.y = 0
}

func (w: Widget&) consume_self() {
}

p.describe()
p.reset()
w.consume_self()
```

Receivers aren't a separate concept — they follow the identical read / `mut` / consume ladder, just written before the method name. `consume_self` is the receiver-side version of §3: calling it is `w`'s last legal use, same as passing `w` to a free function taking `Widget&`.

---

## 6. Shared Values

### 6.1 Construction

```vertex
var a = shared(Widget(1))
```

Cardinality (single-owner vs. shared) is a separate axis from convention. `shared(...)` opts into reference counting — semantically `std::shared_ptr` by way of the mandatory-`make_shared` discipline — without changing which of the three call-site conventions apply. Because `shared(...)` is the *only* construction path, the counts always live adjacent to the object in one allocation; §10 is where that decision pays off a second time.

### 6.2 Read

```vertex
inspect(a)
```

A read of a shared value is exactly as silent, and just as static, as a read of a unique value.

### 6.3 Mutate

```vertex
rename(mut a, "x")
```

`mut` looks identical whether the target is unique or shared, but enforcement differs underneath: unique exclusivity is checked statically at compile time (§9); shared exclusivity is checked at runtime, since two owners could plausibly mutate concurrently through different `shared_ptr`-style handles. The sigil hides that difference on purpose.

### 6.4 Promotion (unique → shared)

```vertex
var u = Widget(2)
var s = shared(u&)
```

Promoting a live unique value into shared is still a move — `u` is visibly consumed, and using it afterward is the same use-after-move error as §3.5. No implicit promotion.

### 6.5 Type Form

```vertex
var a: shared<Widget> = shared(Widget(1))

func take(w: shared<Widget>) {
}
```

`shared<Widget>` and `Widget` are distinct types with no implicit conversion between them. Crossing over is always an explicit, visible act, in either direction.

---

## 7. Conditional Move (compile error forms)

### 7.1 Branch Move

```vertex
var w = Widget(1)

if cond {
    var x = w&
}

inspect(w)      // error: possibly moved value `w`
```

If `w` is moved on some paths and not others, the checker doesn't try to prove which branch ran — `w` is dead for the rest of the function regardless (Invariant D). Cruder than Rust's flow-sensitive analysis, deliberately, in exchange for a rule that fits in one sentence.

### 7.2 Loop Move

```vertex
var w = Widget(1)

for i in 0..3 {
    var x = w&    // error: `w` moved inside loop body
}
```

A move inside a loop body kills the variable before the back-edge, so the second iteration sees a dead variable at compile time — never a runtime double-free.

---

## 8. Illegal Forms (no silent degradation)

```vertex
func archive(w: Widget&) { }

var w = Widget(1)
archive(w)          // error: consume parameter requires `&`

func rename(w: mut Widget) { }

var v = Widget(1)
rename(v)           // error: mut parameter requires `mut` at call site
```

Invariant E: a consume site without `&` is a compile error, never an implicit copy — contrast C++, where omitting `std::move` just copies instead of moving, silently changing performance characteristics with no diagnostic. A mut site without `mut` is likewise a compile error, never a hidden mutation — contrast C++'s silent `T&`. The sigils are contracts enforced by the compiler, not hints that can be dropped.

---

## 9. Exclusivity

```vertex
func both(a: mut Widget, b: mut Widget) { }

var w = Widget(1)
both(mut w, mut w)   // error: `w` passed as two mut arguments

func readAndMut(a: Widget, b: mut Widget) { }

readAndMut(w, mut w) // error: `w` read while mut-borrowed
```

---

## 10. Weak References (`shared<T>` only)

Weak references exist for exactly one reason: `shared<T>` cycles leak.
Plain ownership can't cycle — single ownership is a tree by
construction — but nothing stops two shared objects from holding each
other, and with no tracing GC, a strong count that never reaches zero
means `deinit` never runs. Rust has the same hole with `Rc` and ships
`Weak` as the answer; Swift ships `weak` under ARC. Vertex follows,
and scopes the feature to `shared<T>` only: weakness is a fact about
*counted* ownership, so a type that has no count has nothing to be
weak against.

### 10.1 Construction

```vertex
var a = shared(Widget(1))
var w = weak(a)              // borrow — `a` unaffected
```

`weak(a)` takes `a` bare, not `a&` — the deliberate asymmetry with
§6.4. Promotion consumes because ownership actually transfers; a weak
reference transfers nothing, so it's constructed from a borrow. The
strong count is untouched; only the weak count ticks. Per the design
principle, silence means safe: creating a weak can't destroy or leak
anything.

This is where §6.1's mandatory-`shared(...)` decision pays off a
second time. `weak_ptr` is *the reason* `shared_ptr` is two words —
it forces a separately-allocatable control block. Vertex's counts are
always co-allocated with the object, so the allocation simply grows
from `{count, object}` to `{strong, weak, object}` and **`weak<T>`
stays one word**, pointing at the same block. The cases that force
`weak_ptr` fat are not expressible here — the same move as the
`shared` handle itself.

### 10.2 Type Form

```vertex
var w: weak<Widget> = weak(a)

func track(w: weak<Widget>) {
}
```

`weak<Widget>`, `shared<Widget>`, and `Widget` are three distinct
types, no implicit conversions among them — §6.5's rule extended to
the third cardinality. A weak follows the same read / `mut` / consume
conventions as everything else (§4); none of them touch the strong
count.

### 10.3 Upgrade

```vertex
if let s = w.upgrade() {     // s: shared<Widget>
    inspect(s)
}

let s = w.upgrade() ?? fallback
```

`upgrade()` is the only access path, and it returns `shared<Widget>?`
— increment-strong-if-nonzero, the standard `weak_ptr::lock()`
operation. The return type is the whole safety story: the language
already has `if let` and `??`, so weak access invents no new control
flow, and the null niche means `shared<Widget>?` is still one word.
The upgraded `s` is an ordinary shared owner holding its own +1,
released at scope end like any other.

### 10.4 Dead Weak

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(a&)

if let s = w.upgrade() {
    // not reached — no strong owners remain
}
```

The lifetime split is the standard `make_shared` trade, stated
honestly: **`deinit` runs when the strong count hits zero; the
allocation is freed when strong and weak both hit zero.** A lingering
weak pins the memory footprint, never the object — the widget's
resources are released on time, but the `{strong, weak}` header (and,
because counts are co-allocated, the object's slot) stays resident
until the last weak dies. C++ has the identical caveat with
`make_shared` + `weak_ptr`; Vertex just makes it unavoidable instead
of optional, in exchange for the one-word handle.

### 10.5 Conventions

```vertex
inspect2(w)           // read — bare, no sigil
retarget(mut w)       // mutate — rebind to another target
consume(w&)           // consume — moves the weak handle
```

Nothing new: the §4 ladder applies to `weak<T>` unchanged. A borrow
passes the word with no count traffic (§1's story); a move transfers
which name owns the weak +1 without changing how many weaks exist
(§3's story). The conventions are orthogonal to cardinality — that's
the point of keeping them as separate axes.

### 10.6 Illegal Forms

```vertex
var u = Widget(1)
var w = weak(u)       // error: `weak` requires shared<Widget>, found Widget

let s = w.value       // error: weak<Widget> has no direct access — upgrade first
```

A weak to a plain `Widget` is rejected at the type level: with no
count to check liveness against, it would be a dangling pointer with a
nicer name — the exact C escape hatch this language exists to close.
And there is no direct dereference, no `is_alive` predicate, no path
that observes the target without taking a strong +1 first: an
`is_alive` check would be stale the instant it returned (another owner
can drop between the check and the use), so the API simply doesn't
offer the race. Upgrade-then-use is the only shape, and it's
correct by construction.