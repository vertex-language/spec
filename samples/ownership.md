## Ownership & Access

---

## 0. Overview

Vertex has one storage default and three access conventions. Nothing here is
inferred: the convention lives in the signature, and the choice between copying
and transferring lives at the call site, spelled with a single marker.

| Convention | Parameter form | Call site | Meaning |
| --- | --- | --- | --- |
| shared | `x: T` | bare | read-only view; the caller keeps the value |
| exclusive | `x: mut T` | bare | the callee may write through it |
| owning | `x: var T` | bare or `var`-marked | callee takes the value; bare copies, `var` transfers |

**A note on the examples below.** Several show a call to a function declared
elsewhere in the file, and a few show a signature with an empty body to put the
convention under discussion on one line. Those bodyless lines are sketches, not
source; every real declaration carries a block.

The running types for the whole file:

```vertex
struct Point {
    x: int32
    y: int32
}

class Widget {
    id:  int32
    log: []string = []
}

func (w: Widget) init(id: int32) {
    w.id = id
}
```

An `init` receiver is implicitly exclusive and is written bare (foundation §25),
which is why `init` above assigns `w.id` without a `mut` qualifier.

---

## 0.1 Storage — Stack by Default

A value lives where it is declared. There is no implicit boxing: `Widget(1)` is
a stack value exactly as `Point{x: 0, y: 0}` is, and a class differs from a
struct in its member and method model, not in where it sits (foundation §27).

The only paths to the heap are the two heap constructors:

```vertex
var u = unique(Widget(1))     // sole owner, O(1) transfer
var s = shared(Widget(1))     // refcounted, many readers
```

`unique`, `shared`, and `weak` are keywords with their own construction form
(grammar, *Type-operator and constructor calls*) — they are not ordinary calls
over reserved names.

---

## 1. Shared Access (default)

A bare parameter is a shared, read-only view. It is the default because it is
the cheapest thing a signature can promise: the callee may read the value and
may not write through it, and the caller's binding is untouched by the call.

```vertex
func inspect(w: Widget) {
    print(w.id)
}

let w = Widget(1)
inspect(w)
inspect(w)          // ok — shared access does not consume
```

A shared parameter costs nothing to pass and imposes nothing on the caller's
binding: `let` is sufficient, and the value survives every call.

---

## 2. Exclusive Access — `mut`

`mut` on a parameter says the callee may write through the binding. The write is
visible to the caller when the call returns.

```vertex
func rename(w: mut Widget, tag: string) {
    w.log.push(tag)
}

var w = Widget(1)
rename(w, "draft")          // bare — exclusive access is never spelled at the call
```

Two rules follow from the signature alone:

* **The call site is bare.** Exclusive access is checked through the signature,
  so there is no marker to write. This is the opposite of `var` (§3), where the
  marker at the call is the entire difference between two legal behaviours.
* **The caller's binding must be `var`.** A `let` binding is fixed after
  initialization (foundation §2), so it cannot be passed where a callee may
  write.

`mut` applies to any type, not just classes:

```vertex
func increment(n: mut int32) {
    n += 1
}

var count = 0
increment(count)
```

A method receiver takes the same qualifier, with the same consequences:

```vertex
func (w: mut Widget) rename(tag: string) {
    w.log.push(tag)
}

w.rename("draft")           // `w` must be a `var` binding
```

---

## 3. Transfer — `var`

The marker is the same word at both ends. `var` in a parameter declares the
owning convention; `var` at a call site says *this particular use* transfers
rather than copies.

```vertex
func archive(w: var Widget) {
    storage.push(var w)     // `push` is itself owning — move it onward
}
```

Both call forms are legal against that one signature, and they mean different
things:

```vertex
var w = Widget(1)
archive(var w)      // TRANSFER — O(1); `w` is dead afterwards
inspect(w)          // error: use of transferred value `w`
```

```vertex
var w = Widget(1)
archive(w)          // COPY — bare; cost depends on the payload (§11)
inspect(w)          // ok — `w` was never consumed
```

The same marker works in a binding, which is how a value is moved without a call
in between:

```vertex
var w = Widget(1)

let final = var w   // TRANSFER
let backup = w      // COPY
```

Transfers chain, and each one kills the binding it came from:

```vertex
var w = Widget(1)
var a = var w
var b = var a

archive(var b)      // `w`, `a`, and `b` are all dead at this point
```

```vertex
var w = Widget(1)
var a = w           // COPY — `w` survives
var b = var a       // TRANSFER — `a` dead

inspect(w)          // ok
inspect(a)          // error: use of transferred value `a`
```

### 3.1 Where the Marker Is Legal

`var` in expression position is legal only in an *owning position* — the
right-hand side of a declaration or assignment, an argument, an element of a
tuple / array / map / composite literal, a returned expression, or the binding of
a consuming `for` loop (grammar, *Owning positions*).

```vertex
var w                            // error: transfer outside owning position
if var w { }                     // error: transfer outside owning position
let x = (var w, 1)               // ok — a tuple element is an owning position
```

Both errors above are diagnostics, not syntax errors: `var w` as a statement
parses as a declaration and `if var w` parses as `"var" UnaryExpr`, precisely so
each can be reported against a real node.

### 3.2 What the Marker May Name

The operand is a binding or a field path, never a computed expression. There is
nowhere for a transfer out of a temporary to leave a hole, so the form is
rejected rather than given a meaning.

```vertex
let x = var self.render.buffers.staging   // ok — field path
let y = var pick(a, b)                    // error: transfer requires a binding
                                          //        or field path
let z = var items[0]                      // error: index paths are excluded
```

### 3.3 There Is No Method Form

`transfer` is a reserved name bound to nothing (grammar, *Reserved builtin
names*). It exists so that both spellings a reader might reach for diagnose
against the rule rather than as an unknown identifier:

```vertex
archive(w.transfer())      // error: transfer is the `var` call-site marker
archive(transfer(w))       // error: transfer is the `var` call-site marker
```

`archive(var w)` is the whole of the feature.

### 3.4 Consuming a Container

The marker attaches to the loop *binding*, because what moves is each element,
one per iteration — not the container. The container is dead after the loop.

```vertex
for var f in frames {
    q.submit(var f)
}

inspect(frames)             // error: use of transferred value `frames`
```

`for f in var frames` parses — the iterable is an expression, and `var` over an
expression is one — and is rejected (foundation §21.2). It is not the same
statement written differently.

---

## 4. Conventions Summary

```vertex
func f1(x: T)          // shared    — bare, always
func f2(x: mut T)      // exclusive — bare, checked via signature
func f3(x: var T)      // owning    — transfer/copy chosen at the call site
```

```vertex
f1(x)                  // shared
f2(x)                  // exclusive
f3(x)                  // owning, COPY
f3(var x)              // owning, TRANSFER
```

```vertex
let a = x              // COPY
let b = var x          // TRANSFER
```

The asymmetry is deliberate. Two of the three conventions have exactly one call
shape, so the reader never has to look for a marker to know what happened. The
third has two, and the marker is what distinguishes them.

---

## 5. Method Receivers

A receiver takes the same three qualifiers, with the same meanings:

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
```

```vertex
p.describe()
p.reset()              // `p` must be a `var` binding
w.consume_self()       // always transfers — there is no bare form
```

A `var` receiver is the one place the transfer is unmarked at the call, because
there is no second behaviour to choose between: the method consumes its receiver
by declaration. To keep the original alive, copy first and consume the copy:

```vertex
let backup = w             // COPY
backup.consume_self()      // transfers the copy; `w` still alive
```

---

## 6. Heap Values

### 6.1 `shared T`

`shared T` is a refcounted heap handle. Copying the handle bumps the count;
every copy reads the same object.

```vertex
var a = shared(Widget(1))

inspect(a)                 // shared access — bare
rename(a, "x")             // exclusive access — bare
```

The three conventions apply to a `shared T` unchanged, and a `shared T` is an
ordinary type, so it is legal in a field, a local, an annotation, or a parameter:

```vertex
var a: shared Widget = shared(Widget(1))

func take(w: shared Widget) {
}
```

### 6.2 `unique T`

`unique T` is a sole-owner heap handle. It is the type where the copy/transfer
distinction is most visible, because the two costs are furthest apart:

```vertex
var u = unique(Widget(1))
var v = var u          // TRANSFER — O(1), header only
var w = u              // COPY — allocates and deep-copies the pointee
```

```vertex
var u: unique Widget = unique(Widget(1))

func take(w: unique Widget) {
}
```

---

## 7. Conditional Transfer

A transfer must be unambiguous at every use, so a binding transferred on *some*
paths is treated as transferred on all of them.

```vertex
var w = Widget(1)

if cond {
    let x = var w
}

inspect(w)      // error: possibly transferred value `w`
```

A transfer inside a loop body is rejected outright, since the second iteration
would move an already-dead binding:

```vertex
var w = Widget(1)

for i in 0..3 {
    let x = var w    // error: `w` transferred inside loop body
}
```

Neither diagnostic depends on evaluating `cond` or on the trip count. The rule is
positional.

---

## 8. Owning Parameters — Legal and Illegal Forms

An owning parameter does not force the caller to give the value up. Passing bare
copies it, which is what lets a shared-access function forward to an owning one:

```vertex
func archive(w: var Widget) { }

func inspectAndArchive(w: Widget) {
    archive(w)      // ok — copies `w`; a shared view has nothing to give away
}
```

```vertex
func archive(w: var Widget) { }

var v = Widget(1)
archive(var v)
inspect(v)           // error: use of transferred value `v`
```

Within a single call, one binding cannot be transferred twice, and cannot be both
transferred and read:

```vertex
func both(a: var Widget, b: var Widget) { }

var w = Widget(1)
both(var w, var w)   // error: `w` transferred twice in same call
both(var w, w)       // error: `w` copied while being transferred in same call
```

---

## 9. Exclusivity Checks

Exclusive access is exclusive for the duration of the call, so no two arguments
may reach the same value if either is `mut`:

```vertex
func both(a: mut Widget, b: mut Widget) { }

var w = Widget(1)
both(w, w)           // error: `w` passed as two exclusive-access arguments
```

```vertex
func readAndMut(a: Widget, b: mut Widget) { }

readAndMut(w, w)     // error: `w` read while exclusively accessed
```

The receiver counts as one of the paths, which is what catches the case where the
overlap runs through a field:

```vertex
class ClassA {
    b: ClassB
}

class ClassB {
    func mutateA(a: mut ClassA) {
        a.b = ClassB()
    }
}

var a = ClassA()
a.b.mutateA(a)       // error: exclusive access to `a` overlaps receiver `a.b`
```

`typed_ptr T` is the one type these rules do not reach: two copies of a pointer
are two unchecked aliases, and exclusivity there is convention rather than proof
(memory §1).

---

## 10. Weak References

A `weak T` observes a `shared T` without keeping it alive. It is constructed
from a `shared` value and is an ordinary type elsewhere:

```vertex
var a = shared(Widget(1))
var w = weak(a)
```

```vertex
var w: weak Widget = weak(a)

func track(w: weak Widget) {
}
```

### 10.1 `upgrade` and `drop`

Two reserved builtins operate on these handles. The `func` lines below describe
call shapes; they are not declarations that can be written, shadowed, or attached
to a receiver (grammar, *Reserved builtin names*).

```vertex
func upgrade[T](w: weak T) -> (shared T, string)
func drop[T](s: var shared T)
```

`upgrade` is fallible under the standard convention (foundation §35): a live
referent yields a `shared T` and `""`, and a dead one yields the zero value and a
non-empty message. There is no `nil` to compare against and no one-value form.

```vertex
let s, err = upgrade(w)
if err != "" {
    return
}
inspect(s)
```

`drop` releases a `shared` handle early rather than at end of scope. After it, the
weak edge observes the release:

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(var a)

let s, err = upgrade(w)
if err != "" {
    // `s` is the zero value — check before use, as always
}
```

### 10.2 Conventions Apply Unchanged

A `weak T` is passed like anything else. The convention comes from the signature;
only the owning one has a call-site choice:

```vertex
func inspect2(w: weak Widget)   { }
func retarget(w: mut weak Widget) { }
func consume(w: var weak Widget)  { }

inspect2(w)             // shared    — bare
retarget(w)             // exclusive — bare
consume(w)              // owning, COPY — bare
consume(var w)          // owning, TRANSFER
```

---

## 11. Copy vs. Transfer (cost model)

```
copy (bare):          copy header + copy payload   O(data)
transfer (marked):    copy header only              O(1)
```

The marker is worth spelling because the two costs are not close for any type
with a payload. A frame buffer makes the point at a scale that shows up in a
profile:

```vertex
class Frame {
    pixels: []byte      // 4K RGBA ≈ 33 MB
    pts:    int64
}

func (q: mut EncodeQueue) submit(f: var Frame) {
    q.pending.push(var f)
}
```

```vertex
var frame = cam.capture()
applyFilter(frame)                // mut, bare — free

q.submit(var frame)               // TRANSFER — ~free
q.submit(frame)                   // COPY — 33 MB duplicated
```

Read as a table, the whole cost model of a call site is visible in the call site:

```vertex
inspect(frame)               // bare — free, shared read
applyFilter(frame)           // bare — free, exclusive access
q.submit(var frame)          // marked — ~free, explicit transfer
q.submit(frame)              // bare — O(data), implicit deep copy
```

The last line is the one this design exists to make legible. It is legal, and it
is sometimes what you want; it is never what you got without writing it.

Under generics the cost is decided by the concrete type substituted at
instantiation, and a generic body cannot see which — so a lint on large owned
types fires per instantiation, not per declaration (generics §7).

---

## 12. Back-References — `shared T` / `weak T`

Two objects that point at each other cannot both hold `shared` handles: the
refcounts keep each other above zero and neither is ever released. The back edge
takes `weak T` instead.

```vertex
class FileSession {
    active_chunk: DataChunk
    session_key:  string = "AUTH_TKT_XYZ"
}

class DataChunk {
    parent:  weak FileSession
    payload: []byte = []
}

func (c: DataChunk) init(parent: weak FileSession) {
    c.parent = parent
}
```

The edge is installed *after* construction, not inside `init`. `weak(...)`
requires a `shared` referent (§10), and inside an initializer the receiver is not
yet a `shared` handle — there is nothing to observe. A factory function is the
shape that works:

```vertex
func newSession() -> shared FileSession {
    let s = shared(FileSession())
    s.active_chunk = DataChunk(parent: weak(s))
    return s
}
```

Reading through the back edge is the ordinary fallible pattern — the parent may
be gone, and that is a condition, not a crash:

```vertex
func (c: DataChunk) validate_and_process() {
    let s, err = upgrade(c.parent)
    if err != "" {
        return
    }
    let key = s.session_key
}
```

| | `shared` back-edge | `weak T` back-edge |
| --- | --- | --- |
| Read cost | O(1) pointer load | O(1) plus an atomic liveness check |
| Cycle behaviour | refcount cycle — neither end is ever released | parent released normally; the edge goes dead |
| Access after the parent dies | unreachable — the parent cannot die | `upgrade()` returns a non-empty error string |
| Checked | nothing to check, and nothing is freed | at every read, by the caller |

The trade is one atomic check per read against a leak that no amount of care at
the call sites will find.