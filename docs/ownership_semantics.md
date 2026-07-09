# Vertex Language Reference: Ownership & Access Semantics

## Specification 2.5 — Semantics & Rationale

Companion to `ownership.md`, same section numbers. Includes the same
code as `ownership.md` plus the reasoning behind each form.

**Why not "borrow."** Borrowing is a checkout-desk metaphor: you take
something, you give it back, there's a timeline. That's not what the
compiler does. It never hands anything anywhere — it looks at one call
site and asks two questions: *is anyone else reading this while I write
it, and is this memory still alive?* Those questions have names already,
from the literature this system actually comes from: **Aliasing**,
**Mutation**, **Liveness**, and the **Law of Exclusivity** that ties them
together.

**Lineage.** `unique_ptr` gives single-owner, move-only semantics at
zero runtime cost; `shared_ptr` gives refcounted multi-ownership for
graph/cycle cases; RAII gives scope-based cleanup with no manual
bookkeeping. Swift's exclusivity enforcement is the closest existing
system to what `mut` does here. Vertex goes further than Swift by
making references second-class (Rule 0), which is what lets it skip
lifetime annotations entirely rather than infer them. §12 imports one
more idea from the C++ canon: the non-owning raw back-pointer inside a
`unique_ptr` parent-child pair — legal there by discipline, legal here
by proof.

**Design principle: mark what the compiler can't catch for you.**
Shared Access can't destroy anything, so it's silent. Exclusive Access
is marked at both ends as a standing reminder. Move is fully policed
by Move Invalidation, so `own` drops its call-site mark. And `unowned`
is silent at every use site because the entire danger was discharged
once, at the anchoring statement, by a structural proof — after that
there is nothing left for ink to warn about.

**Spelling rule.** The convention lives in type position — name on the
left of the colon, contract on the right: `x: T` is shared, `x: mut T`
is exclusive, `x: own T` moves, and in field position `unowned f: T`
anchors. One slot, four values.

---

## 0. The Root Concepts

**Aliasing** is having more than one pathway to the same memory at
once. **Mutation** is writing through one of those pathways. **Liveness**
is the guarantee that memory hasn't been destroyed while a pathway to
it still exists. The most common liveness failure in unmanaged
languages is a struct holding a pathway to an object that's already
gone — Vertex's entire design is aimed at that one failure mode.

**Law of Exclusivity:** Aliasing (Shared Access) and Mutation
(Exclusive Access) on the same memory are mutually exclusive at compile
time.

**Rule 0 — access is second-class.** A `mut` grant is not a value —
it's a temporary right, scoped to exactly one call:

- Not storable in a field → no dangling field.
- Not returnable → nothing outlives its call, so no lifetime
  annotations are ever needed.
- Not capturable by a closure → closures close over owned values or
  copies, never over access grants.

This deletes the escaping-reference problem instead of checking for
it. Rule 0 has exactly two exceptions, and both are exceptions for the
same underlying reason — they are statements about *ownership
structure*, which is permanent and compiler-visible, not about
*access*, which is fleeting:

- **`own`** isn't temporary access, it's a change of owner, so nothing
  about it needs to evaporate at the end of a call — the callee
  legitimately keeps it.
- **`unowned`** (§12) is a stored pathway that doesn't own. On its
  face that is the exact thing Rule 0 forbids — and it is permitted
  anyway, deliberately, because it only exists where the compiler can
  see a strict ownership tree. Rule 0 answers the Liveness question
  *temporally* (the pathway dies with the call, so it can't dangle).
  §12 answers the same question *structurally* (the pathway's target
  provably outlives the pathway's container, so it can't dangle
  either). Two different proofs, one guarantee. Rule 0 is not the
  goal; Liveness is. Where a structural proof delivers Liveness,
  breaking Rule 0 costs nothing.

---

## 1. Shared Access (default)

```vertex
func inspect(w: Widget) {
    print(w.id)
}

let w = Widget(1)
inspect(w)
inspect(w)
```

A bare name grants read-only access to memory that's still fully
owned elsewhere — like `const T&` in C++, but with no sigil, since this
is the overwhelmingly common case. This silence is trustworthy because
a Shared Access parameter can be passed further down but never
returned, stored, or outlived — Rule 0, read side.

---

## 2. Exclusive Access — `mut`

### 2.1 Declaration

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}
```

Granting Exclusive Access doesn't end the variable's life the way a
move does — `w` is still `w` when the call returns — but the Law of
Exclusivity means nothing else may hold any pathway into that memory
for the duration, so it earns its own keyword.

### 2.2 Call Site

```vertex
var w = Widget(1)
rename(mut w, "draft")
```

`mut` is echoed at the call site because a mutating call leaves `w`
alive and outwardly unchanged in shape — the value might come back
different, and the only thing that tells a reader so is the word
sitting right there in the call.

### 2.3 Mut Parameters (functions, non-methods)

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(mut count)
```

### 2.4 Mut Receivers

```vertex
func (w: mut Widget) rename(tag: string) {
    w.log.push(tag)
}

w.rename("draft")
```

---

## 3. Move — `own`

### 3.1 Declaration

```vertex
func archive(w: own Widget) {
    storage.push(w)
}
```

### 3.2 Call Site

```vertex
var w = Widget(1)
archive(w)
```

No keyword. This is the one destructive operation in the language,
and it's silent on purpose: the signature already declared `archive`
as `own`, and Move Invalidation (§3.5) guarantees any later use of `w`
is a compile error.

### 3.3 Move Into a Binding

```vertex
var w = Widget(1)
var final = w
```

### 3.4 Chained Moves

```vertex
var w = Widget(1)
var a = w
var b = a

archive(b)
```

### 3.5 Use-After-Move (compile error)

```vertex
var w = Widget(1)
var final = w
inspect(w)          // error: use of moved value `w`
```

C++ permits this and calls it undefined behavior. Vertex catches it at
the use site. Note that Move Invalidation is not merely a convenience
of the `own` convention — it is also the load-bearing wall under §12:
"the parent uniquely owns the child" is only a stable fact because
every move of ownership kills the previous name. Anchored references
lean on that fact for their entire safety story.

---

## 4. Conventions Summary (grammar forms)

```vertex
func f1(x: T)          // shared access — bare, no keyword
func f2(x: mut T)       // exclusive access — keyword in signature
func f3(x: own T)       // move — keyword in signature

f1(x)                  // shared access — bare, no keyword
f2(mut x)               // exclusive access — keyword at call site
f3(x)                   // move — bare, no keyword at call site
```

| convention        | C++ (spelling)         | Vertex        |
|-------------------|------------------------|---------------|
| shared access (default) | `const T&`        | bare          |
| exclusive access  | `T&`                   | `mut`         |
| move              | `T` / `std::move`      | `own`         |
| move at call site | `std::move(x)`         | `x` (silent, checked) |
| exclusive at call site | *(silent)*        | `mut x` REQUIRED |
| stored back-edge  | raw `T*` (discipline)  | `unowned` (proved, §12) |

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

func (w: own Widget) consume_self() {
}
```

Receivers follow the identical shared / exclusive / move ladder, just
written before the method name.

---

## 6. Shared Values (`shared<T>`)

### 6.1 Construction

```vertex
var a = shared(Widget(1))
```

Cardinality (single-owner vs. shared) is a separate axis from access
convention.

### 6.2 Read

```vertex
inspect(a)
```

### 6.3 Mutate

```vertex
rename(mut a, "x")
```

Unique exclusivity is checked statically (§9); shared exclusivity is
checked at runtime.

### 6.4 Promotion (unique → shared)

```vertex
var u = Widget(2)
var s = shared(u)
```

Promotion consumes `u` — same use-after-move error as §3.5 afterward.
Note the interaction with §12: an anchored value can never take this
path (§12.5), which is precisely how the "strict tree" precondition
stays true for the life of the anchor.

### 6.5 Type Form

```vertex
var a: shared<Widget> = shared(Widget(1))

func take(w: shared<Widget>) {
}
```

---

## 7. Conditional Move (compile error forms)

### 7.1 Branch Move

```vertex
var w = Widget(1)

if cond {
    var x = w
}

inspect(w)      // error: possibly moved value `w`
```

Liveness has to be provable, not merely likely.

### 7.2 Loop Move

```vertex
var w = Widget(1)

for i in 0..3 {
    var x = w    // error: `w` moved inside loop body
}
```

---

## 8. Illegal Forms (no silent degradation)

```vertex
func archive(w: own Widget) { }

func inspectAndArchive(w: Widget) {
    archive(w)      // error: cannot move out of a shared-access value `w`
}

func rename(w: mut Widget) { }

var v = Widget(1)
rename(v)           // error: exclusive-access parameter requires `mut` at call site
```

---

## 9. Exclusivity Checks

```vertex
func both(a: mut Widget, b: mut Widget) { }

var w = Widget(1)
both(mut w, mut w)   // error: `w` passed as two exclusive-access arguments

func readAndMut(a: Widget, b: mut Widget) { }

readAndMut(w, mut w) // error: `w` read while exclusively accessed
```

The Law of Exclusivity is checked at every call site, and the receiver
counts as a live pathway:

```vertex
class ClassB {
    func mutateA(a: mut ClassA) { a.b = ClassB() }
}
class ClassA { b: ClassB }

var a = ClassA()
a.b.mutateA(mut a)   // error: exclusive access to `a` overlaps
                     //        the receiver `a.b`
```

If the method held Exclusive Access to all of `a` while `a.b` is the
thing executing it, `a.b = ClassB()` would destroy the very object
that's running. The fix is granting access to the disjoint part
actually needed:

```vertex
a.b.mutateName(mut a.name)   // ok — receiver a.b and argument a.name
                              //      are disjoint paths
```

With §12, the parent-child pattern above usually stops needing a `mut`
argument at all — the child reaches the parent through its own anchor —
but the receiver-inclusive check does not relax. It generalizes: the
anchor is one more pathway the call site must count (§12.6).

---

## 10. Weak References (`shared<T>` only)

Weak references exist for exactly one reason: `shared<T>` cycles leak.
Plain ownership can't cycle — single ownership is a tree by
construction — but nothing stops two shared objects from holding each
other.

### 10.1 Construction

```vertex
var a = shared(Widget(1))
var w = weak(a)              // shared access — `a` unaffected
```

### 10.2 Type Form

```vertex
var w: weak<Widget> = weak(a)
```

### 10.3 Upgrade

```vertex
if let s = w.upgrade() {     // s: shared<Widget>
    inspect(s)
}
```

`upgrade()` is the only access path — increment-strong-if-nonzero.
This runtime branch is the price of a back-edge whose target's
lifetime the compiler *cannot* see. §12 is what you get when it can.

### 10.4 Dead Weak

```vertex
drop(a)

if let s = w.upgrade() {
    // not reached — no strong owners remain
}
```

### 10.5 Conventions

```vertex
inspect2(w)           // shared access — bare, no keyword
retarget(mut w)       // exclusive access — rebind to another target
consume(w)            // move — bare, no keyword
```

### 10.6 Illegal Forms

```vertex
var u = Widget(1)
var w = weak(u)       // error: `weak` requires shared<Widget>, found Widget

let s = w.value       // error: weak<Widget> has no direct access — upgrade first
```

A weak to a plain `Widget` is rejected at the type level — for the
proved-tree case, `unowned` (§12) is the correct tool, not `weak`.

---

## 11. Clone vs. Move (cost model)

```
clone:  copy header + copy the 33 MB it points to     (deep)    O(data)
move:   copy header, period                           (shallow)  O(1)
```

### 11.1 Example

```vertex
class Frame {
    pixels: [uint8]
    pts:    int64
}

func (q: mut EncodeQueue) submit(f: own Frame) {
    q.pending.push(f)
}

var frame = cam.capture()
applyFilter(mut frame)

q.submit(frame)
q.submit(frame.clone())
```

### 11.2 Conventions vs. Cost (extends §4)

```vertex
inspect(frame)           // bare    — free, temporary look at the original
applyFilter(mut frame)   // mut     — free, temporary exclusive access
q.submit(frame)          // own     — ~free, header copy
q.submit(frame.clone())  // clone   — O(data)
b.parent                 // unowned — free, one pointer, zero checks
w.upgrade()              // weak    — runtime branch + count traffic
```

Every back-edge in the language now has a stated price, and the free
one is fenced by a compile-time proof rather than programmer
discipline.

### 11.3 Illegal Forms

```vertex
q.submit(frame)
render(frame)            // error: use of moved value `frame`

q.submit(frame.clone())
render(frame)            // ok — the original was never moved
```

---

## 12. Anchored References — `unowned`

**Law of Anchoring:** `unowned` is free but only exists where the
compiler can see a strict ownership tree.

**What it is.** An `unowned` field is a stored pathway that doesn't
own — nakedly, the thing Rule 0 forbids. Vertex breaks that rule here
on purpose, and the reason it's safe to break is the Law of Anchoring
itself. Rule 0 exists to guarantee Liveness by making every access
grant die with its call. An anchor guarantees the same Liveness a
different way: the ownership tree already dictates destruction order.
If A uniquely owns B, then B is destroyed strictly before A — always,
on every path, by construction. A pointer from B back to A therefore
*cannot* dangle, not because anyone checked at runtime, but because
the universe in which it dangles is unrepresentable. The compiler
isn't trusting the programmer the way C++ trusts a raw `ClassA*`; it
is verifying, at one statement, that the tree shape holds, and then
the guarantee is permanent.

**What it compiles to.** One machine pointer. No control block, no
strong count, no weak count, no upgrade branch, no nil check, no
generated retain/release. Reading `b.parent` is a load. This is the
zero-cost abstraction: the entire safety apparatus runs at compile
time and leaves nothing in the binary.

### 12.1 Declaration (field position only)

```vertex
class ClassB {
    unowned parent: ClassA
    name: string = "Class B"
}

class ClassA {
    b: ClassB
    name: string = "Class A"
}
```

Field-only placement isn't a stylistic restriction — it's what keeps
the proof to one shape. A temporary look at a parent inside a call is
already free via Shared Access; the only thing genuinely new here is
*storage*, so storage is the only thing the keyword grants.

### 12.2 Initialization — the anchoring form

```vertex
func (a: ClassA) init() {
    a.b = ClassB(parent: a)    // ok — `a` becomes B's unique owner
                               //      in this same statement
}

var orphan = ClassB(parent: a) // error: `orphan` is not owned by `a`
```

This single check *is* the borrow checker replacement. The compiler
never reasons about lifetimes in general — it verifies one syntactic
shape: **anchor target = the object the child is being stored into.**
If that shape holds, ownership and back-pointer are born in the same
statement and can never disagree afterward, because §12.5 forbids
every operation that could make them disagree. The whole proof is
local to one line of source.

### 12.3 Use

```vertex
func (b: ClassB) mutateParent() {
    b.parent.name = "mutated by B"
}

var a = ClassA()
a.b.mutateParent()
```

Use sites are silent — bare field access — by the marking principle:
there is nothing left at the use site for the compiler to fail to
catch, so there is nothing for ink to say.

### 12.4 Late Attachment — `attach`

```vertex
func (t: mut Tree) attach(n: NodeSpec) {
    t.nodes.push(Node(tree: t, spec: n))
}
```

Children created after the parent's `init` are legal when construction
and ownership-storage happen in one statement inside a method of the
owner. The atomicity is the point: there is never a window where an
anchored child exists un-owned.

### 12.5 Pinning

```vertex
var stolen = a.b          // error: `b` is anchored to `a` — cannot move out
var s = shared(a.b)       // error: anchored value cannot be promoted
q.submit(a.b)             // error: anchored value cannot be moved
                          //        to an `own` parameter
```

Pinning is the Law of Anchoring enforced over time. The anchoring form
(§12.2) proves the tree shape at birth; pinning ensures no later
operation can carry the pointer into a scope where A's death is no
longer ordered after B's. Moving an anchored value to a new owner, or
promoting it to `shared`, would do exactly that — so both are
unrepresentable. Internal moves that preserve the owner (a dynamic
array field of A reallocating, A itself being moved *with* B inside
it) don't disturb the invariant: the tree moved as a tree.

### 12.6 Exclusivity (extends §9)

A stored back-pointer is *standing aliasing* — the one cost of
breaking Rule 0 that doesn't disappear. It never threatens Liveness
(that's proved), but it does mean B permanently holds a pathway into
A, and the Law of Exclusivity has to account for it:

```vertex
mutateVia(mut a, a.b)     // error: `a.b.parent` aliases `a`
                          //        while `a` is exclusively accessed
```

Enforcement: each method of an anchored type carries an inferred
touches-parent effect, computed bottom-up (a method has the effect if
it accesses the anchor or calls a method that does). At every call
site, an anchored argument or receiver whose method-set-in-play has
the effect counts as a live Shared or Exclusive pathway into the
parent, and the ordinary §9 check runs. No new user-facing syntax —
the same dataflow pass already owed for §7 handles it.

This is also where the C++ original quietly under-delivers: the raw
`ClassA*` pattern is memory-safe but says nothing about aliased
mutation. Vertex keeps the zero cost and closes that hole too.

### 12.7 Deinit Blackout

```vertex
func (b: ClassB) deinit() {
    print(b.parent.name)     // error: `parent` is not accessible
                             //        during deinit
}
```

Teardown runs parent-body-first, then fields; during B's `deinit`,
A's memory exists but its invariants are already dismantled. Rather
than define partially-destroyed semantics, the anchor is statically
dark inside `deinit`. This mirrors the spirit of §7: accessibility
must be provable, and here it provably isn't.

### 12.8 Illegal Forms

```vertex
func take(p: unowned ClassA) { }     // error: `unowned` is field-only
let local: unowned ClassA = ...      // error: `unowned` is field-only
func give() -> unowned ClassA { }    // error: `unowned` is field-only

let f = func() { b.parent.touch() }  // error: closure cannot capture an
                                     //        anchored value
```

The closure ban is Rule 0's ghost: a closure outlives call scopes by
design, and a captured anchored value would smuggle the back-pointer
out of the tree the same way a stored `mut` would smuggle out an
access grant. Same disease, same cure — unrepresentable.

### 12.9 The Two Back-Edges

```
shared<T> graph, cycles possible, lifetime invisible → weak<T>
    price: control block, counts, upgrade branch per access
    proof: none — checked at runtime, every time

unique tree, no cycles, lifetime visible             → unowned
    price: one pointer, zero checks
    proof: once, at the anchoring statement, forever
```

Same question — *is the target still alive?* — answered at runtime
where the compiler can't see, and at compile time where it can.
`unowned` is free but only exists where the compiler can see a strict
ownership tree; `weak` is the fallback for everywhere it can't.

---

## Known Obligations

1. **Receiver-inclusive exclusivity** (§9, §12.6) — every call site's
   check must treat the receiver chain *and* anchored back-edges as
   live pathways.
2. **Move dataflow** (§3, §7) — "is `w` dead here?" after a move inside
   a branch or loop needs a real dataflow pass, not a syntactic kill.
3. **Touches-parent inference** (§12.6) — the per-method effect must
   stay tractable through function values; current position: closures
   cannot capture anchored values (§12.8), which keeps the effect
   computation first-order.
4. **Attach forms** (§12.4) — decide whether the single-statement
   construct-and-store rule is expressive enough, or whether a blessed
   `attach` intrinsic is needed for containers of anchored children.
5. **Mutable globals / reentrancy** — `f(mut g)` calling `h()`, which
   reads global `g` directly, has overlapping access even though each
   call site looks clean alone. Current position: mutable globals are
   banned.