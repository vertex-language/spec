# Vertex Language Specification — Ownership & Access

---

## 1. The Root Concepts

Three things are being managed, not a checkout system:

* **Aliasing** — more than one pathway to the same memory at once.
* **Mutation** — writing through one of those pathways.
* **Liveness** — the memory hasn't been destroyed while a pathway to it still exists.

**Law of Exclusivity:** you may have Aliasing (**Shared Access**) or Mutation (**Exclusive Access**) on a given piece of memory, never both at the same time.

Everything in this spec is one of three answers to one question: when a value is handed to a new position, what does the destination get?

* a **shared view** of it (read-only alias),
* **exclusive access** to it (temporary, mutating, non-owning), or
* **ownership** of it (the original, or an independent copy).

Sections 4–6 cover these three in that order. Everything else — receivers, heap types, weak references, the cost model — is those three rules applied in specific places.

---

## 2. Storage — Stack by Default

Both **structs** and **classes** are stack-resident value types by default:

* **`struct`** — inline data, no identity. Lives on the stack (or inline wherever it's embedded), copied by value under Rule 0 (§6.1).
* **`class`** — same storage story as `struct`: stack-resident, copied by value under Rule 0. A `class` differs from a `struct` in its member/method model, *not* in where its bytes live. Declaring something a `class` does not, by itself, put it on the heap.

Neither kind is heap-allocated on its own. The **only** ways onto the heap are:

* **`unique(Expr)`** — a uniquely-owned heap allocation (§8.1). Exactly one owner at a time; transfers under the same rules as any other owning position, just relocating a header instead of the whole payload. No refcount, no `upgrade()`.
* **`shared(Expr)`** — a reference-counted heap allocation (§8.2), cloneable as a cheap handle, and the only kind `weak T` (§9) can observe.

Built-in dynamic containers (e.g. `[T]` arrays) are the one exception: their backing storage is heap-allocated implicitly, since "grow at runtime" is incompatible with fixed stack layout. That heap block is still owned the normal way — through whatever `struct`/`class`/`unique`/`shared` wrapper holds the array. Rule 0 governs copying or transferring the *handle* to it exactly as it does everything else.

---

## 3. The Three Conventions — Road Map

A function author picks a convention per parameter, in the signature. A caller writes at most one thing at the call site — `var` — and only when the parameter is owning.

```vertex
func f1(x: T)          // shared access — bare, no keyword, ever
func f2(x: mut T)      // exclusive access — keyword in signature only
func f3(x: var T)      // owning — keyword in signature; transfer/copy set at call site
```

```vertex
f1(x)                  // shared — bare, always
f2(x)                  // exclusive — bare, checked via signature
f3(x)                  // owning, COPY — bare, deep-copies x
f3(var x)              // owning, TRANSFER — explicit, x dies here
```

The same pattern governs bindings:

```vertex
let a = x              // COPY — bare, x survives
let b = var x          // TRANSFER — explicit, x dies here
```

The marker is the same word at both ends: `var` in the parameter declares the owning convention, and `var` at the call site says this use transfers rather than copies.

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

Bare — no keyword, no copy, no transfer. `inspect` only borrows; nothing about ownership is in play, so the copy/transfer question never arises.

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

No keyword at the call site. Whether `w` may be mutated by this call is determined entirely by `rename`'s signature. `mut` never takes ownership, so it never copies either — this is always the original, accessed exclusively for the duration of the call.

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

The Law of Exclusivity (§1) is enforced at every call site. The compiler reads the callee's signature to know which parameters are exclusive; dropping the call-site keyword weakens human-readability at the call site, not enforcement.

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
a.b.mutateA(a)        // error: exclusive access to `a` overlaps receiver `a.b`
```

---

## 6. Ownership — `var`

### 6.1 Rule 0 — one marker, two meanings, read by presence

Wherever an *existing binding* is handed to a new position — the right-hand side of an assignment, or an argument passed to an owning (`var`-typed) parameter — prefixing `var` to that binding means **move**: the source dies, the destination becomes the sole owner, checked statically (§6.7). Omitting `var` at that same position means **copy**: the compiler performs a deep copy automatically, the source stays alive, and the destination is an independent original.

There is no `.clone()` method. Copying is not a call you make; it's what happens when you *don't* write `var`.

Rule 0 does not apply to a freshly constructed value (`Widget(1)`) — there's no existing binding to preserve, so there's nothing to transfer or copy; the temporary is simply consumed into the destination.

`mut` is unrelated to this rule — it never takes ownership, so the transfer/copy question never arises for it (§5).

### 6.2 Declaration

```vertex
func archive(w: var Widget) {
    storage.push(w)
}
```

A `var`-typed parameter takes ownership. What ownership it receives — the caller's original, or a fresh copy — is decided at the call site by Rule 0, not by this declaration.

### 6.3 Call Site — Explicit Transfer

```vertex
var w = Widget(1)
archive(var w)
inspect(w)          // error: use of transferred value `w`
```

### 6.4 Call Site — Omitted, Falls Back to Copy

```vertex
var w = Widget(1)
archive(w)             // no marker — deep copy
inspect(w)             // ok
```

`archive` still receives ownership of *something* — in this branch, a brand-new, independent copy. `w` itself is completely unaffected.

The same rule makes forwarding from a shared parameter legal:

```vertex
func inspectAndArchive(w: Widget) {
    archive(w)      // ok — copies `w`
}
```

### 6.5 Transfer vs. Copy Into a Binding

```vertex
var w = Widget(1)

let final = var w      // TRANSFER
let backup = w         // COPY
```

Both are legal in the same scope only if the copy happens before the transfer consumes `w`, or if the transfer never happens at all — ordinary use-after-transfer rules apply once `var` is written (§6.7).

### 6.6 Chained Transfers

```vertex
var w = Widget(1)
var a = var w
var b = var a

archive(var b)
```

Each `var` marks that specific hop as a move. Omitting any one of them turns that hop into a copy instead, and the chain after it continues from the copy, not the original:

```vertex
var w = Widget(1)
var a = w              // COPY — w survives
var b = var a          // TRANSFER — a dead

inspect(w)             // ok
inspect(a)             // error: use of transferred value `a`
```

### 6.7 Use-After-Transfer (compile error)

```vertex
var w = Widget(1)
let final = var w
inspect(w)          // error: use of transferred value `w`
```

Liveness is tracked statically through control flow:

```vertex
var w = Widget(1)

if cond {
    let x = var w
}

inspect(w)      // error: possibly transferred value `w`
```

```vertex
var w = Widget(1)

for i in 0..3 {
    let x = var w    // error: `w` transferred inside loop body
}
```

A single call may not consume the same binding twice, nor read it while consuming it — evaluation order would otherwise decide liveness:

```vertex
func both(a: var Widget, b: var Widget) { }

var w = Widget(1)
both(var w, var w)   // error: `w` transferred twice in same call
both(var w, w)       // error: `w` copied while being transferred in same call
```

### 6.8 The `var` Marker Rules

The marker takes a binding or a field path, never a computed expression. It is legal **only** directly in an owning position: the right-hand side of a binding, an argument to a `var`-typed parameter, a returned expression, or the iterable of a consuming loop. Anywhere else is a compile error:

```vertex
var w                            // error: transfer outside owning position
if var w { }                     // error: transfer outside owning position
let x = (var w, 1)               // ok — tuple element is owning position
```

It is not composable through arbitrary expressions:

```vertex
let x = var self.render.buffers.staging   // ok — field path
let y = var pick(a, b)                    // error: transfer requires a binding or field path
```

### 6.9 Consuming Loops

The consuming loop marks the binding, not the iterable — each element moves out into `f`, and the container is dead after the loop:

```vertex
for var f in frames {
    q.submit(var f)
}

inspect(frames)                 // error: use of transferred value `frames`
```

The bare form (`for f in frames`) iterates by shared access as always; `mut` iteration is unchanged.

---

## 7. Method Receivers

All three conventions apply to the receiver position:

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

Receiver position has no argument-list slot to carry a `var` marker, so `w.consume_self()` transfers `w` unconditionally — there is no bare form that copies here. This is the one exception to Rule 0's "bare means copy". To pass a copy to an owning receiver, copy first, using the same bare-assignment rule as everywhere else:

```vertex
let backup = w             // COPY
backup.consume_self()      // transfers the copy; w still alive
```

---

## 8. Heap Ownership — `unique T` and `shared T`

### 8.1 Unique Heap Values (`unique T`)

```vertex
var u = unique(Widget(1))
```

`unique(Expr)` allocates on the heap and hands back sole ownership, with no refcount and no `upgrade()` machinery. Once constructed, a `unique T` binding is governed by the ordinary transfer/copy rules for any owning position:

```vertex
var u = unique(Widget(1))
var v = var u          // TRANSFER — O(1)
var w = u              // COPY — deep-copies pointee
```

**Type form:**

```vertex
var u: unique Widget = unique(Widget(1))

func take(w: unique Widget) {
}
```

### 8.2 Shared Values (`shared T`)

```vertex
var a = shared(Widget(1))
```

Reads and mutations use the ordinary conventions from §4 and §5 — the handle is passed bare either way, and the callee's signature decides:

```vertex
inspect(a)
rename(a, "x")
```

**Type form:**

```vertex
var a: shared Widget = shared(Widget(1))

func take(w: shared Widget) {
}
```

`shared T` itself is a reference-counted handle — passing the handle around (`take(a)`) is always a cheap refcount bump, never a deep copy of the underlying `T`, regardless of transfer/bare.

### 8.3 Promotion (unique → shared)

```vertex
var u = Widget(2)
var s = shared(u)
```

`shared(u)` consumes `u` — this is construction of a new wrapper around a fresh value, not a binding hand-off, so Rule 0 doesn't apply; `u` is moved into the wrapper unconditionally, same as any constructor call.

---

## 9. Weak References (`shared T` only)

A `weak T` observes a `shared T` allocation without keeping it alive.

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
let s, err = upgrade(w)
if err != "" {
    return
}
inspect(s)
```

### 9.4 Dead Weak

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(a)

let s, err = upgrade(w)
if err != "" {
    // s is zero-value
}
```

### 9.5 Conventions

A `weak T` binding is itself an ordinary value, so the three conventions apply to it unchanged:

```vertex
inspect2(w)             // shared — bare
retarget(w)             // exclusive — bare
consume(w)              // owning, COPY — bare
consume(var w)          // owning, TRANSFER
```

---

## 10. Copy vs. Transfer (cost model)

There is no separate copy operation to name — copying is simply the absence of `var`.

```
copy (bare):          copy header + copy payload   O(data)
transfer (marked):    copy header only              O(1)
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
applyFilter(frame)                // mut, bare

q.submit(var frame)               // TRANSFER — ~free
q.submit(frame)                   // COPY — 33 MB duplicated
```

### 10.2 Conventions vs. Cost

```vertex
inspect(frame)               // bare — free, shared read
applyFilter(frame)           // bare — free, exclusive access
q.submit(var frame)          // marked — ~free, explicit transfer
q.submit(frame)              // bare — O(data), implicit deep copy
```

---

## 11. Back-References — `shared T` / `weak T`

Every back-edge goes through `shared T`/`weak T` (§8/§9).

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
    let s, err = upgrade(c.parent)
    if err == "" {
        let key = s.session_key
    }
}
```

| | Zero-cost back-edge | `weak T` |
|---|---|---|
| Read cost | O(1) pointer load | O(1) + atomic check |
| Cycle safety | Compiler-proved | Runtime |
| Deinit access | Compile error | Error tuple from `upgrade()` |