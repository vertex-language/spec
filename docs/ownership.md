# Vertex Language Grammar

## Specification 2.2 — Ownership

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

---

## 2. Mutation — `mut`

### 2.1 Declaration

```vertex
func rename(mut w: Widget, tag: string) {
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

## 3. Consume — postfix `&`

### 3.1 Declaration

```vertex
func archive(w: Widget&) {
    storage.push(w&)
}
```

### 3.2 Call Site

```vertex
var w = Widget(1)
archive(w&)
```

### 3.3 Move Into a Binding

```vertex
var w = Widget(1)
var final = w&
```

### 3.4 Chained Moves

```vertex
var w = Widget(1)
var a = w&
var b = a&

archive(b&)
```

### 3.5 Use-After-Move (compile error)

```vertex
var w = Widget(1)
var final = w&
inspect(w)          // error: use of moved value `w`
```

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

---

## 6. Shared Values

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
var s = shared(u&)
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
    var x = w&
}

inspect(w)      // error: possibly moved value `w`
```

### 7.2 Loop Move

```vertex
var w = Widget(1)

for i in 0..3 {
    var x = w&    // error: `w` moved inside loop body
}
```

---

## 8. Illegal Forms (no silent degradation)

```vertex
func archive(w: Widget&) { }

var w = Widget(1)
archive(w)          // error: consume parameter requires `&`

func rename(mut w: Widget) { }

var v = Widget(1)
rename(v)           // error: mut parameter requires `mut` at call site
```

---

## 9. Exclusivity

```vertex
func both(mut a: Widget, mut b: Widget) { }

var w = Widget(1)
both(mut w, mut w)   // error: `w` passed as two mut arguments

func readAndMut(a: Widget, mut b: Widget) { }

readAndMut(w, mut w) // error: `w` read while mut-borrowed
```