# Vertex Language Grammar

## Grammar — Ownership & Access (Grammar Reference)

---

## 0. Storage — Stack by Default

```vertex
struct Point { x: int32 y: int32 }
class Widget { id: int32 }

// only heap paths:
var u = unique(Widget(1))
var s = shared(Widget(1))
```

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

---

## 2. Exclusive Access — `mut`

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}

var w = Widget(1)
rename(w, "draft")
```

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(count)
```

```vertex
func (w: mut Widget) rename(tag: string) {
    w.log.push(tag)
}

w.rename("draft")
```

---

## 3. Transfer — `var` / `.transfer()`

```vertex
func archive(w: var Widget) {
    storage.push(w)
}
```

```vertex
var w = Widget(1)
archive(w.transfer())
inspect(w)          // error: use of transferred value `w`
```

```vertex
var w = Widget(1)
archive(w)             // no .transfer() — deep copy
inspect(w)             // ok
```

```vertex
var w = Widget(1)

let final = w.transfer()   // TRANSFER
let backup = w              // COPY
```

```vertex
var w = Widget(1)
var a = w.transfer()
var b = a.transfer()

archive(b.transfer())
```

```vertex
var w = Widget(1)
var a = w              // COPY — w survives
var b = a.transfer()   // TRANSFER — a dead

inspect(w)             // ok
inspect(a)             // error: use of transferred value `a`
```

```vertex
var w = Widget(1)
let final = w.transfer()
inspect(w)          // error: use of transferred value `w`
```

```vertex
w.transfer()                    // error: transfer outside owning position
if w.transfer() { }              // error: transfer outside owning position
let x = (w.transfer(), 1)        // ok — tuple element is owning position
```

```vertex
for f in frames.transfer() {
    q.submit(f.transfer())
}

inspect(frames)                 // error: use of transferred value `frames`
```

---

## 4. Conventions Summary

```vertex
func f1(x: T)          // shared — bare, always
func f2(x: mut T)      // exclusive — bare, checked via signature
func f3(x: var T)      // owning — transfer/copy set at call site
```

```vertex
f1(x)                  // shared
f2(x)                  // exclusive
f3(x)                  // owning, COPY
f3(x.transfer())       // owning, TRANSFER
```

```vertex
let a = x              // COPY
let b = x.transfer()   // TRANSFER
```

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

func (w: var Widget) consume_self() {
}

p.describe()
p.reset()
w.consume_self()       // always transfers
```

```vertex
let backup = w             // COPY
backup.consume_self()      // transfers the copy; w still alive
```

---

## 6. Shared Values (`shared T`)

```vertex
var a = shared(Widget(1))
```

```vertex
inspect(a)
```

```vertex
rename(a, "x")
```

```vertex
var u = Widget(2)
var s = shared(u)
```

```vertex
var a: shared Widget = shared(Widget(1))

func take(w: shared Widget) {
}
```

```vertex
var u = unique(Widget(1))
```

```vertex
var u = unique(Widget(1))
var v = u.transfer()   // TRANSFER — O(1)
var w = u              // COPY — deep-copies pointee
```

```vertex
var u: unique Widget = unique(Widget(1))

func take(w: unique Widget) {
}
```

---

## 7. Conditional Transfer

```vertex
var w = Widget(1)

if cond {
    let x = w.transfer()
}

inspect(w)      // error: possibly transferred value `w`
```

```vertex
var w = Widget(1)

for i in 0..3 {
    let x = w.transfer()    // error: `w` transferred inside loop body
}
```

---

## 8. Illegal / Legal Forms

```vertex
func archive(w: var Widget) { }

func inspectAndArchive(w: Widget) {
    archive(w)      // ok — copies `w`
}
```

```vertex
func archive(w: var Widget) { }

var v = Widget(1)
archive(v.transfer())
inspect(v)           // error: use of transferred value `v`
```

```vertex
func both(a: var Widget, b: var Widget) { }

var w = Widget(1)
both(w.transfer(), w.transfer())   // error: `w` transferred twice in same call
```

```vertex
both(w.transfer(), w)   // error: `w` copied while being transferred in same call
```

---

## 9. Exclusivity Checks

```vertex
func both(a: mut Widget, b: mut Widget) { }

var w = Widget(1)
both(w, w)   // error: `w` passed as two exclusive-access arguments

func readAndMut(a: Widget, b: mut Widget) { }

readAndMut(w, w) // error: `w` read while exclusively accessed
```

```vertex
class ClassB {
    func mutateA(a: mut ClassA) { a.b = ClassB() }
}
class ClassA { b: ClassB }

var a = ClassA()
a.b.mutateA(a)        // error: exclusive access to `a` overlaps receiver `a.b`
```

---

## 10. Weak References

```vertex
var a = shared(Widget(1))
var w = weak(a)
```

```vertex
var w: weak Widget = weak(a)

func track(w: weak Widget) {
}
```

```vertex
let s, err = w.upgrade()
if err != "" {
    return
}
inspect(s)
```

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(a)

let s, err = w.upgrade()
if err != "" {
    // s is zero-value
}
```

```vertex
inspect2(w)             // shared — bare
retarget(w)             // exclusive — bare
consume(w)              // owning, COPY — bare
consume(w.transfer())   // owning, TRANSFER
```

---

## 11. Copy vs. Transfer (cost model)

```
copy (bare):          copy header + copy payload   O(data)
transfer (marked):    copy header only              O(1)
```

```vertex
class Frame {
    pixels: [uint8]      // 4K RGBA ≈ 33 MB
    pts:    int64
}

func (q: mut EncodeQueue) submit(f: var Frame) {
    q.pending.push(f)
}

var frame = cam.capture()
applyFilter(frame)                // mut, bare

q.submit(frame.transfer())        // TRANSFER — ~free
q.submit(frame)                   // COPY — 33 MB duplicated
```

```vertex
inspect(frame)               // bare — free, shared read
applyFilter(frame)           // bare — free, exclusive access
q.submit(frame.transfer())   // marked — ~free, explicit transfer
q.submit(frame)              // bare — O(data), implicit deep copy
```

---

## 12. Back-References — `shared T` / `weak T`

```vertex
class FileSession {
    active_chunk: DataChunk
    session_key:  string = "AUTH_TKT_XYZ"
}

class DataChunk {
    parent: weak FileSession
    payload: [uint8]
}

func (s: shared FileSession) init() {
    s.active_chunk = DataChunk(parent: weak(s))
}

func (c: DataChunk) validate_and_process() {
    let s, err = c.parent.upgrade()
    if err == "" {
        let key = s.session_key
    }
}
```

| | Zero-cost back-edge | `weak T` |
| --- | --- | --- |
| Read cost | O(1) pointer load | O(1) + atomic check |
| Cycle safety | Compiler-proved | Runtime |
| Deinit access | Compile error | Error tuple from `upgrade()` |
```

---

## ownership_spec.md

```markdown
# Vertex Language Grammar

## Specification — Ownership & Access

---

## 1. The Root Concepts

Three things are being managed, not a checkout system:

1. **Aliasing** — more than one pathway to the same memory at once.
2. **Mutation** — writing through one of those pathways.
3. **Liveness** — the memory hasn't been destroyed while a pathway to
   it still exists.

**Law of Exclusivity:** you may have Aliasing (**Shared Access**) or
Mutation (**Exclusive Access**) on a given piece of memory, never both
at the same time.

Everything in this spec is one of three answers to one question: when
a value is handed to a new position, what does the destination get?

* a **shared view** of it (read-only alias),
* **exclusive access** to it (temporary, mutating, non-owning), or
* **ownership** of it (the original, or an independent copy).

Sections 4–6 cover these three in that order. Everything else —
receivers, heap types, weak references, the cost model — is those
three rules applied in specific places.

---

## 2. Storage — Stack by Default

Both **structs** and **classes** are stack-resident value types by
default:

* **`struct`** — inline data, no identity. Lives on the stack (or
  inline wherever it's embedded), copied by value under Rule 0 (§6.1).
* **`class`** — same storage story as `struct`: stack-resident, copied
  by value under Rule 0. A `class` differs from a `struct` in its
  member/method model, *not* in where its bytes live. Declaring
  something a `class` does not, by itself, put it on the heap.

Neither kind is heap-allocated on its own. The **only** ways onto the
heap are:

* **`unique(Expr)`** — a uniquely-owned heap allocation (§8.1).
  Exactly one owner at a time; transfers under the same rules as any
  other owning position, just relocating a header instead of the whole
  payload. No refcount, no `.upgrade()`.
* **`shared(Expr)`** — a reference-counted heap allocation (§8.2),
  cloneable as a cheap handle, and the only kind `weak T` (§9) can
  observe.

Built-in dynamic containers (e.g. `[T]` arrays) are the one exception:
their backing storage is heap-allocated implicitly, since "grow at
runtime" is incompatible with fixed stack layout. That heap block is
still owned the normal way — through whatever `struct`/`class`/
`unique`/`shared` wrapper holds the array. Rule 0 governs copying or
transferring the *handle* to it exactly as it does everything else.

---

## 3. The Three Conventions — Road Map

A function author picks a convention per parameter, in the signature.
A caller writes at most one thing at the call site — `.transfer()` —
and only when the parameter is owning.

```vertex
func f1(x: T)          // shared access — bare, no keyword, ever
func f2(x: mut T)      // exclusive access — keyword in signature only
func f3(x: var T)      // owning — keyword in signature; transfer/copy set at call site
```

```vertex
f1(x)                  // shared — bare, always
f2(x)                  // exclusive — bare, checked via signature
f3(x)                  // owning, COPY — bare, deep-copies x
f3(x.transfer())       // owning, TRANSFER — explicit, x dies here
```

The same pattern governs bindings:

```vertex
let a = x              // COPY — bare, x survives
let b = x.transfer()   // TRANSFER — explicit, x dies here
```

Bare copies, `.transfer()` moves — identically, whether the
destination is a function argument or a local binding. That symmetry
is the whole point of the design (there is no `.clone()`; see §6.1).

The signature keyword and the call-site intrinsic are deliberately
different spellings: `var` marks the *destination convention*
(author's side), `.transfer()` marks the *source consumption*
(caller's side). Neither can be mistaken for the other, and a mutable
declaration (`var w = ...`) never collides visually with a transfer.

---

## 4. Shared Access (default)

```vertex
func inspect(w: Widget) {
    print(w.id)
}

let w = Widget(1)
inspect(w)
inspect(w)
```

Bare — no keyword, no copy, no transfer. `inspect` only borrows;
nothing about ownership is in play, so the copy/transfer question
never arises.

---

## 5. Exclusive Access — `mut`

### 5.1 Declaration

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}
```

### 5.2 Call Site

```vertex
var w = Widget(1)
rename(w, "draft")
```

No keyword at the call site. Whether `w` may be mutated by this call
is determined entirely by `rename`'s signature. `mut` never takes
ownership, so it never copies either — this is always the original,
accessed exclusively for the duration of the call.

### 5.3 Mut Parameters (functions, non-methods)

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(count)
```

### 5.4 Mut Receivers

```vertex
func (w: mut Widget) rename(tag: string) {
    w.log.push(tag)
}

w.rename("draft")
```

### 5.5 Exclusivity Checks

The Law of Exclusivity (§1) is enforced at every call site. The
compiler reads the callee's signature to know which parameters are
exclusive; dropping the call-site keyword weakens human-readability at
the call site, not enforcement.

```vertex
func both(a: mut Widget, b: mut Widget) { }

var w = Widget(1)
both(w, w)   // error: `w` passed as two exclusive-access arguments

func readAndMut(a: Widget, b: mut Widget) { }

readAndMut(w, w) // error: `w` read while exclusively accessed
```

Overlap through a field path is caught the same way:

```vertex
class ClassB {
    func mutateA(a: mut ClassA) { a.b = ClassB() }
}
class ClassA { b: ClassB }

var a = ClassA()
a.b.mutateA(a)        // error: exclusive access to `a` overlaps
                       //        the receiver `a.b`
```

---

## 6. Ownership — `var` / `.transfer()`

### 6.1 Rule 0 — one marker, two meanings, read by presence

Wherever an *existing binding* is handed to a new position — the
right-hand side of an assignment, or an argument passed to an owning
(`var`-typed) parameter — appending `.transfer()` to that binding
means **move**: the source dies, the destination becomes the sole
owner, checked statically (§6.7). Omitting `.transfer()` at that same
position means **copy**: the compiler performs a deep copy
automatically, the source stays alive, and the destination is an
independent original.

There is no `.clone()` method. Copying is not a call you make; it's
what happens when you *don't* write `.transfer()`.

The two markers work as a pair: the **function author** declares an
owning parameter with `var` in the signature; the **caller** decides
what ownership it receives — the original via `.transfer()`, or a
fresh copy via a bare argument. Ownership transfer is a two-party
handshake: the author signs in the signature, the caller signs at the
call site.

Rule 0 does not apply to a freshly constructed value (`Widget(1)`) —
there's no existing binding to preserve, so there's nothing to
transfer or copy; the temporary is simply consumed into the
destination.

`mut` is unrelated to this rule — it never takes ownership, so the
transfer/copy question never arises for it (§5).

### 6.2 Declaration

```vertex
func archive(w: var Widget) {
    storage.push(w)
}
```

A `var`-typed parameter takes ownership. What ownership it receives —
the caller's original, or a fresh copy — is decided at the call site
by Rule 0, not by this declaration.

### 6.3 Call Site — Explicit Transfer

```vertex
var w = Widget(1)
archive(w.transfer())
inspect(w)          // error: use of transferred value `w`
```

### 6.4 Call Site — Omitted, Falls Back to Copy

```vertex
var w = Widget(1)
archive(w)             // no `.transfer()` — Vertex deep-copies `w`
inspect(w)             // ok — `w` was never transferred, this is the original
```

`archive` still receives ownership of *something* — in this branch, a
brand-new, independent copy. `w` itself is completely unaffected.

The same rule makes forwarding from a shared parameter legal:

```vertex
func inspectAndArchive(w: Widget) {
    archive(w)      // ok — copies `w`, does not transfer it
}
```

**Cost note:** this is the one place an unmarked call site can
silently cost O(data) instead of O(1) — see §10. There is no compiler
error for this; a lint flagging bare `var`-parameter arguments whose
type carries non-trivial owned data is recommended, not required.

### 6.5 Transfer vs. Copy Into a Binding

```vertex
var w = Widget(1)

let final = w.transfer()   // TRANSFER — w is dead after this line
let backup = w             // COPY — w is untouched, backup is independent
```

Both are legal in the same scope only if the copy happens before the
transfer consumes `w`, or if the transfer never happens at all —
ordinary use-after-transfer rules apply once `.transfer()` is written
(§6.7).

### 6.6 Chained Transfers

```vertex
var w = Widget(1)
var a = w.transfer()
var b = a.transfer()

archive(b.transfer())
```

Each `.transfer()` marks that specific hop as a move. Omitting any one
of them turns that hop into a copy instead, and the chain after it
continues from the copy, not the original:

```vertex
var w = Widget(1)
var a = w              // COPY — w survives
var b = a.transfer()   // TRANSFER — a is dead, b owns the copy

inspect(w)             // ok — w was never touched
inspect(a)             // error: use of transferred value `a`
```

### 6.7 Use-After-Transfer (compile error)

```vertex
var w = Widget(1)
let final = w.transfer()
inspect(w)          // error: use of transferred value `w`
```

Liveness is tracked statically through control flow:

```vertex
var w = Widget(1)

if cond {
    let x = w.transfer()
}

inspect(w)      // error: possibly transferred value `w`
```

```vertex
var w = Widget(1)

for i in 0..3 {
    let x = w.transfer()    // error: `w` transferred inside loop body
}
```

Both errors depend on `.transfer()` actually being written at the
transfer site. The bare form (`let x = w`) inside either branch or
loop is legal — it copies every iteration instead, at O(data) cost per
iteration, with no error and no warning beyond the optional lint from
§6.4.

A single call may not consume the same binding twice, nor read it
while consuming it — evaluation order would otherwise decide liveness:

```vertex
func both(a: var Widget, b: var Widget) { }

var w = Widget(1)
both(w.transfer(), w.transfer())   // error: `w` transferred twice in the same call
both(w.transfer(), w)              // error: `w` copied while being transferred
                                    //        in the same call
```

### 6.8 `.transfer()` Is an Intrinsic

`.transfer()` is compiler-known and has method spelling only. It is
spelled as a method call because it behaves like one to the reader and
appears in completion on every value — but the compiler treats it as a
transfer marker, not a dispatchable call. The rules:

* Defined on every type automatically; never declared, never
  overridden. `func (w: var Widget) transfer()` is a compile error:
  `transfer` is a reserved member name.
* Legal **only** directly in an owning position: the right-hand side
  of a binding, an argument to a `var`-typed parameter, a returned
  expression, or the iterable of a consuming loop (§6.9). Anywhere
  else is a compile error:

```vertex
w.transfer()                    // error: transfer outside owning position
if w.transfer() { }             // error: transfer outside owning position
let x = (w.transfer(), 1)       // ok — tuple element is an owning position
```

* Not composable through arbitrary expressions. The receiver must be a
  plain binding (or field path the checker can prove unique — see
  §5.5); `(cond ? a : b).transfer()` is rejected.
* Takes no arguments. `w.transfer(x)` is a compile error.

### 6.9 Consuming Loops

```vertex
for f in frames.transfer() {    // consuming — moves elements out,
    q.submit(f.transfer())      // container dead after the loop
}

inspect(frames)                 // error: use of transferred value `frames`
```

The bare form (`for f in frames`) iterates by shared access as always
(foundation §21); `mut` iteration is unchanged. `.transfer()` on the
iterable is the consuming form.

---

## 7. Method Receivers

All three conventions from §3 apply to the receiver position:

```vertex
func (p: Point) describe() {       // shared receiver
    let n = p.x
}

func (p: mut Point) reset() {      // exclusive receiver
    p.x = 0
    p.y = 0
}

func (w: var Widget) consume_self() {   // owning receiver
}

p.describe()
p.reset()
w.consume_self()       // always transfers — see note below
```

Receiver position has no argument-list slot to carry a `.transfer()`
marker, so `w.consume_self()` transfers `w` unconditionally — there is
no bare form that copies here. This is the one exception to Rule 0's
"bare means copy". To pass a copy to an owning receiver, copy first,
using the same bare-assignment rule as everywhere else:

```vertex
let backup = w             // bare — COPY
backup.consume_self()      // transfers the copy; w is still alive
```

(`w.transfer().consume_self()` is legal but redundant — the receiver
position of an owning method is already an owning position, and the
bare receiver already transfers. A lint may flag the redundant marker.)

---

## 8. Heap Ownership — `unique T` and `shared T`

§2 named the two doors onto the heap. Both are ordinary values once
constructed; what differs is how many owners they permit.

### 8.1 Unique Heap Values (`unique T`)

```vertex
var u = unique(Widget(1))
```

`unique(Expr)` allocates on the heap and hands back sole ownership,
with no refcount and no `.upgrade()` machinery. It consumes a freshly
constructed value — there's no existing binding being handed off, so
Rule 0 doesn't apply to the `unique(...)` call itself.

Once constructed, a `unique T` binding is governed by the ordinary
transfer/copy rules for any owning position — Rule 0 applies exactly
as it does for a stack-resident `struct`/`class`, just relocating a
header instead of copying the payload on a transfer:

```vertex
var u = unique(Widget(1))
var v = u.transfer()   // TRANSFER — header only, O(1); u is dead
var w = u              // (if u were still alive) COPY — deep-copies the pointee
```

**Type form:**

```vertex
var u: unique Widget = unique(Widget(1))

func take(w: unique Widget) {
}
```

If you later need more than one owner, or a weak observer, promote
with `shared(...)` (§8.3) — there is no direct `unique T` →
`weak T` path; it always goes through `shared T` first.

### 8.2 Shared Values (`shared T`)

```vertex
var a = shared(Widget(1))
```

Reads and mutations use the ordinary conventions from §4 and §5 — the
handle is passed bare either way, and the callee's signature decides:

```vertex
inspect(a)          // shared access
rename(a, "x")      // exclusive access, via rename's mut parameter
```

**Type form:**

```vertex
var a: shared Widget = shared(Widget(1))

func take(w: shared Widget) {
}
```

`shared T` itself is a reference-counted handle — passing the handle
around (`take(a)`) is always a cheap refcount bump, never a deep copy
of the underlying `T`, regardless of `.transfer()`/bare. Rule 0
governs unique ownership transfer; `shared T` has already opted out
of unique ownership by construction.

### 8.3 Promotion (unique → shared)

```vertex
var u = Widget(2)
var s = shared(u)
```

`shared(u)` consumes `u` — this is construction of a new wrapper
around a fresh value, not a binding hand-off, so Rule 0 doesn't apply;
`u` is moved into the wrapper unconditionally, same as any constructor
call. Writing `shared(u.transfer())` is legal but redundant, and may
be linted.

---

## 9. Weak References (`shared T` only)

A `weak T` observes a `shared T` allocation without keeping it
alive. It is the language's answer to the Liveness problem from §1
when ownership can't (or shouldn't) be extended.

### 9.1 Construction

```vertex
var a = shared(Widget(1))
var w = weak(a)
```

### 9.2 Type Form

```vertex
var w: weak Widget = weak(a)

func track(w: weak Widget) {
}
```

### 9.3 Upgrade

```vertex
let s, err = w.upgrade()
if err != "" {
    // handle the dead reference (e.g., return, break, or fallback)
    return
}
inspect(s)
```

`.upgrade()` and `.transfer()` are the two intrinsic ownership members
— method-shaped operations the compiler knows. They surface in
completion on the values they apply to, which is where a developer
looks first.

### 9.4 Dead Weak

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(a)

let s, err = w.upgrade()
if err != "" {
    // reached — err will contain a failure string, and s will be a zero-value
}
```

### 9.5 Conventions

A `weak T` binding is itself an ordinary value, so the three
conventions from §3 apply to it unchanged:

```vertex
inspect2(w)             // shared access — bare
retarget(w)             // exclusive access — bare, checked via signature
consume(w)              // owning, COPY — bare
consume(w.transfer())   // owning, TRANSFER — explicit
```

---

## 10. Copy vs. Transfer (cost model)

There is no separate copy operation to name — copying is simply the
absence of `.transfer()`. Both copy and transfer are the same machine
operation at different depths:

```
copy (bare):          copy header + copy the 33 MB it points to  (deep)     O(data)
transfer (marked):    copy header, period                        (shallow)  O(1)
```

### 10.1 Example

```vertex
class Frame {
    pixels: []uint8      // 4K RGBA ≈ 33 MB
    pts:    int64
}

func (q: mut EncodeQueue) submit(f: var Frame) {
    q.pending.push(f)
}

var frame = cam.capture()
applyFilter(frame)                // mut, bare — no copy, no transfer, in place

q.submit(frame.transfer())        // TRANSFER — header copy only, ~free
q.submit(frame)                   // COPY — full 33 MB payload duplicated
```

Note per §2: `Frame` itself is an ordinary stack-resident `class` —
declaring it a `class` didn't put it on the heap. The 33 MB lives in
`pixels`, whose heap storage comes from the array-container exception,
not from `Frame` needing `unique()`/`shared()` to exist. A deep copy
of `frame` therefore means copying the `Frame` header *and* walking
into `pixels`' heap block to duplicate it; a transfer just relocates
the header (and the array's handle inside it) — the array's backing
storage never moves, only its ownership does.

### 10.2 Conventions vs. Cost (extends §3)

```vertex
inspect(frame)               // bare      — free, shared read
applyFilter(frame)           // bare      — free, exclusive access (mut, invisible)
q.submit(frame.transfer())   // marked    — ~free, explicit transfer
q.submit(frame)              // bare      — O(data), implicit deep copy
```

Two very different costs — O(1) and O(data) — are both reachable from
the call site, but only one is keyword-free. The bare form's cost
still depends on the parameter's declared convention (`mut` vs `var`)
in a signature the reader isn't looking at; the marked form is
self-describing. This is the residual cost of removing `.clone()` as
an explicit call: the *cheap* path names itself, the *expensive* path
does not.

### 10.3 The Sharp Edge, and Why It Points This Way

`q.submit(frame.transfer())` and `q.submit(frame)` differ by 33 MB of
hidden work, and there is no compiler error distinguishing them — only
the optional lint from §6.4. This polarity — quiet copy, loud transfer
— is a deliberate choice, not an accident: transfers are rare and
value-killing, so they carry the ceremony; copies are the common
intent of a bare hand-off, so they stay unmarked. The inverse design
(quiet move, loud `.clone()`) makes the *common* case dangerous
(accidental use-after-move for callers who never read the signature)
to make the *rare* case cheap to type. Vertex chooses caller safety:
nothing you don't write can kill your binding. The price is that the
expensive operation is the silent one, which is why the §6.4 lint on
large owned types is strongly recommended in any real toolchain.

---

## 11. Back-References — via `shared T` / `weak T`

`unowned` does not exist in this spec. Every back-edge — a child
holding a reference to something that also owns the child — goes
through `shared T`/`weak T` (§8/§9), paying weak's runtime check
even where the ownership tree is structurally acyclic.

### 11.1 Example

```vertex
class FileSession {
    active_chunk: DataChunk
    session_key:  string = "AUTH_TKT_XYZ"
}

class DataChunk {
    parent: weak FileSession
    payload: []uint8
}

func (s: shared FileSession) init() {
    s.active_chunk = DataChunk(parent: weak(s))
}

func (c: DataChunk) validate_and_process() {
    let s, err = c.parent.upgrade()
    if err == "" {
        let key = s.session_key
    }
}
```

### 11.2 What Was Lost (vs. a hypothetical zero-cost `unowned`)

|  | Zero-cost back-edge | `weak T` (this spec) |
| --- | --- | --- |
| Cost of a back-edge read | O(1), one pointer load | O(1) + atomic check, upgrade branch |
| Cycle safety | Compiler-proved acyclic | Runtime — same mechanism as any cycle |
| Deinit-time access | Compile error | Returns an error tuple from `upgrade()` |

Reintroducing a free tree-only back-edge later is a compiler-inference
feature (proving acyclicity from the initializer graph automatically),
not a syntax addition — worth treating as separate, future work.