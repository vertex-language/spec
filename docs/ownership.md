# Vertex Language Grammar

## Specification 2.5 — Ownership & Access

---

## 0. The Root Concepts

Three things are being managed, not a checkout system:

1. **Aliasing** — more than one pathway to the same memory at once.
2. **Mutation** — writing through one of those pathways.
3. **Liveness** — the memory hasn't been destroyed while a pathway to it
   still exists.

**Law of Exclusivity:** you may have Aliasing (**Shared Access**) or
Mutation (**Exclusive Access**) on a given piece of memory, never both
at the same time.

**Rule 0 — access is second-class.** `mut` marks a grant of Exclusive
Access that exists only for the duration of one call. It may appear in
exactly one place: as an argument at a call site. Not in a field, not
in a local variable, not in a return type, not captured by a closure.

Rule 0 has exactly two exceptions, both of which are ownership facts,
not access grants:

- `own` — ownership transfer. No call-scope restriction: an `own`
  parameter can be stored, returned, or captured, because the callee
  now *is* the owner.
- `unowned` (§12) — a stored pathway that doesn't own. Permitted only
  where the compiler can see a strict ownership tree, because there
  the liveness proof is structural, not temporal.

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

Bare — no keyword. Calling `inspect(w)` twice in a row is fine because
Shared Access never excludes anything else that's also just reading.

---

## 2. Exclusive Access — `mut`

### 2.1 Declaration

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}
```

### 2.2 Call Site

```vertex
var w = Widget(1)
rename(mut w, "draft")
```

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

Field position adds one more form (§12):

```vertex
class B {
    unowned parent: A   // anchored — stored non-owning back-pointer
}
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

func (w: own Widget) consume_self() {
}

p.describe()
p.reset()
w.consume_self()
```

---

## 6. Shared Values (`shared<T>`)

### 6.1 Construction

```vertex
var a = shared(Widget(1))
```

### 6.2 Read

```vertex
inspect(a)
```

### 6.3 Mutate

```vertex
rename(mut a, "x")
```

### 6.4 Promotion (unique → shared)

```vertex
var u = Widget(2)
var s = shared(u)
```

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

A call site's accesses include the receiver: in `a.b.method(mut a)`,
the receiver `a.b` is itself a live pathway into `a` for the duration
of the call, and is counted.

```vertex
class ClassB {
    func mutateA(a: mut ClassA) { a.b = ClassB() }
}
class ClassA { b: ClassB }

var a = ClassA()
a.b.mutateA(mut a)   // error: exclusive access to `a` overlaps
                     //        the receiver `a.b`
```

---

## 10. Weak References (`shared<T>` only)

### 10.1 Construction

```vertex
var a = shared(Widget(1))
var w = weak(a)              // shared access — `a` unaffected
```

### 10.2 Type Form

```vertex
var w: weak<Widget> = weak(a)

func track(w: weak<Widget>) {
}
```

### 10.3 Upgrade

```vertex
if let s = w.upgrade() {     // s: shared<Widget>
    inspect(s)
}

let s = w.upgrade() ?? fallback
```

### 10.4 Dead Weak

```vertex
var a = shared(Widget(1))
var w = weak(a)

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

---

## 11. Clone vs. Move (cost model)

Both operations are copies at the machine level — there is no "move
instruction." A move copies the value's header and leaves the payload
where it is; the name is kept because it describes the contract
(ownership relocates, the source name is dead), not the mechanism.

```
clone:  copy header + copy the 33 MB it points to     (deep)    O(data)
move:   copy header, period                           (shallow)  O(1)
```

### 11.1 Example

```vertex
class Frame {
    pixels: [uint8]      // 4K RGBA ≈ 33 MB
    pts:    int64
}

func (q: mut EncodeQueue) submit(f: own Frame) {
    q.pending.push(f)
}

var frame = cam.capture()        // 33 MB allocated once
applyFilter(mut frame)           // in place — no copy

q.submit(frame)                  // move — header copy, payload untouched
q.submit(frame.clone())          // clone — header copy + full 33 MB copy
```

### 11.2 Conventions vs. Cost (extends §4)

```vertex
inspect(frame)           // bare    — free, temporary look at the original
applyFilter(mut frame)   // mut     — free, temporary exclusive access
q.submit(frame)          // own     — ~free, header copy, the original itself
q.submit(frame.clone())  // clone   — O(data), a second independent original
b.parent                 // unowned — free, one pointer, zero checks (§12)
```

The only operation whose cost scales with the data is the only one
that requires explicit spelling at the call site.

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

An `unowned` field is a stored pathway that doesn't own — the
sanctioned break of Rule 0. It is a raw back-pointer to the object's
unique owner: one machine pointer, no control block, no counts, no
upgrade branch, no runtime check of any kind.

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

### 12.2 Initialization — the anchoring form

```vertex
func (a: ClassA) init() {
    a.b = ClassB(parent: a)    // ok — `a` becomes B's unique owner
                               //      in this same statement
}
```

The back-pointer target must be the object that, in the same
expression, takes unique ownership of the child. Set exactly once, in
`init` of the child, never reassigned.

### 12.3 Use

```vertex
func (b: ClassB) mutateParent() {
    b.parent.name = "mutated by B"
}

var a = ClassA()
a.b.mutateParent()
```

### 12.4 Late Attachment — `attach`

```vertex
class Node {
    unowned tree: Tree
}

class Tree {
    nodes: [Node]
}

func (t: mut Tree) attach(n: NodeSpec) {
    t.nodes.push(Node(tree: t, spec: n))   // ok — ownership and anchor
                                           //      established atomically
}
```

### 12.4 The `unowned` Superpower (Large Data Processing)

When dealing with massive allocations—like gigabyte-sized files, machine learning tensors, or uncompressed video buffers—`unowned` becomes a superpower. It allows a child object to access its broader context without triggering expensive deep copies (`clone`) or destructive ownership transfers (`own`).

```vertex
class FileSession {
    active_chunk: DataChunk
    session_key:  string = "AUTH_TKT_XYZ"
}

class DataChunk {
    unowned parent: FileSession  // The zero-cost structural back-pointer
    payload: [uint8]             // E.g., 2 GBs of memory-mapped data
}

func (s: FileSession) init() {
    // Ownership and the anchor are established atomically in one statement.
    // The strict ownership tree is now mathematically proven.
    s.active_chunk = DataChunk(parent: s)
}

func (c: DataChunk) validate_and_process() {
    // We need the parent's session key to validate this massive chunk.
    // 
    // 1. Calling c.clone() to pass it somewhere would copy 2 GB of RAM.
    // 2. Passing it via `own` would rip it out of the FileSession, 
    //    destroying the tree topology.
    // 3. Using `unowned` gives us a zero-cost hop back to the parent.
    
    let key = c.parent.session_key   // A single O(1) machine pointer load!
    
    // ... process the 2 GBs of c.payload in-place ...
}

```

Anchoring after `init` of the parent is legal only inside a method of
the owner, in a single statement that both constructs the child and
stores it into the owner.

### 12.5 Pinning (compile error forms)

```vertex
var stolen = a.b          // error: `b` is anchored to `a` — cannot move out
var s = shared(a.b)       // error: anchored value cannot be promoted
q.submit(a.b)             // error: anchored value cannot be moved
                          //        to an `own` parameter
```

A type containing an `unowned` field, directly or transitively, is
pinned to its owner. Internal moves that preserve the owner (e.g. a
dynamic array field of the owner reallocating) are fine.

### 12.6 Exclusivity (extends §9)

Any method of the child that reads or writes through its `unowned`
field counts as a live pathway into the parent at the call site:

```vertex
func consumeParent(x: own ClassA) { }

var a = ClassA()
inspectBoth(a, a.b)          // ok — two shared accesses
mutateVia(mut a, a.b)        // error: `a.b.parent` aliases `a`
                             //        while `a` is exclusively accessed
```

### 12.7 Deinit Blackout

```vertex
func (b: ClassB) deinit() {
    print(b.parent.name)     // error: `parent` is not accessible
                             //        during deinit
}
```

Parent teardown runs before field teardown; during the child's
`deinit` the parent's invariants are already gone, so the anchor is
statically inaccessible there.

### 12.8 Illegal Forms

```vertex
func take(p: unowned ClassA) { }     // error: `unowned` is field-only
let local: unowned ClassA = ...      // error: `unowned` is field-only
func give() -> unowned ClassA { }    // error: `unowned` is field-only

var orphan = ClassB(parent: a)       // error: `orphan` is not owned by `a` —
                                     //        anchor target must be the owner

let f = func() { b.parent.touch() }  // error: closure cannot capture an
                                     //        anchored value
```

### 12.9 When to use which back-edge

```
shared<T> graph, cycles possible   →  weak<T>     (runtime-checked, §10)
unique ownership tree, no cycles   →  unowned     (compile-proved, free)
```