## Ownership & Access

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

## 3. Transfer — `var`

The marker is the same word at both ends: `var` in the parameter declares the owning convention, `var` at the call site says this use transfers rather than copies.

```vertex
func archive(w: var Widget) {
    storage.push(w)
}
```

```vertex
var w = Widget(1)
archive(var w)
inspect(w)          // error: use of transferred value `w`
```

```vertex
var w = Widget(1)
archive(w)             // no marker — deep copy
inspect(w)             // ok
```

```vertex
var w = Widget(1)

let final = var w      // TRANSFER
let backup = w         // COPY
```

```vertex
var w = Widget(1)
var a = var w
var b = var a

archive(var b)
```

```vertex
var w = Widget(1)
var a = w              // COPY — w survives
var b = var a          // TRANSFER — a dead

inspect(w)             // ok
inspect(a)             // error: use of transferred value `a`
```

```vertex
var w = Widget(1)
let final = var w
inspect(w)          // error: use of transferred value `w`
```

```vertex
var w                            // error: transfer outside owning position
if var w { }                     // error: transfer outside owning position
let x = (var w, 1)               // ok — tuple element is owning position
```

The marker takes a binding or a field path, never a computed expression:

```vertex
let x = var self.render.buffers.staging   // ok — field path
let y = var pick(a, b)                    // error: transfer requires a binding
                                           //        or field path
```

The consuming loop marks the binding, not the iterable — each element moves out into `f`, and the container is dead after the loop:

```vertex
for var f in frames {
    q.submit(var f)
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
f3(var x)              // owning, TRANSFER
```

```vertex
let a = x              // COPY
let b = var x          // TRANSFER
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
var v = var u          // TRANSFER — O(1)
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
archive(var v)
inspect(v)           // error: use of transferred value `v`
```

```vertex
func both(a: var Widget, b: var Widget) { }

var w = Widget(1)
both(var w, var w)   // error: `w` transferred twice in same call
```

```vertex
both(var w, w)   // error: `w` copied while being transferred in same call
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
let s, err = upgrade(w)
if err != "" {
    return
}
inspect(s)
```

```vertex
var a = shared(Widget(1))
var w = weak(a)

drop(a)

let s, err = upgrade(w)
if err != "" {
    // s is zero-value
}
```

```vertex
inspect2(w)             // shared — bare
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

```vertex
inspect(frame)               // bare — free, shared read
applyFilter(frame)           // bare — free, exclusive access
q.submit(var frame)          // marked — ~free, explicit transfer
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