# Vertex Language Grammar

## Specification 2.2 — Generics

---

## 1. Generic Functions

```vertex
func largest<T>(list: [T]) -> T {
    var largest = list[0]
    for item in list {
        if item > largest { largest = item }
    }
    return largest
}
```

---

## 2. Instantiation

```vertex
largest([3, 1, 4, 1, 5])       // T inferred as int32

largest<float32>([1.0, 2.5])   // explicit type argument
```

---

## 3. Generic Structs

```vertex
struct Stack<T> {
    items: [T] = []
}

func (s: mut Stack<T>) push(item: T) {
    s.items.push(item)
}

func (s: mut Stack<T>) pop() -> T? {
    return s.items.pop()
}
```

```vertex
var s: Stack<int32> = Stack<int32>{}
s.push(1)
s.push(2)
let top = s.pop()   // int32?
```

---

## 4. Multiple Type Parameters

```vertex
struct Pair<A, B> {
    first:  A
    second: B
}

func swap<A, B>(p: Pair<A, B>) -> Pair<B, A> {
    return Pair<B, A>{first: p.second, second: p.first}
}
```

---

## 5. Generic Enums

```vertex
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

```vertex
let r: Result<int32, string> = .Ok(42)

switch r {
case .Ok(v):
case .Err(e):
}
```

---

## 6. Ownership Sigils with Type Parameters

Type parameters compose with `mut` / `&` exactly like concrete types (see Ownership §4).

```vertex
func consume<T>(x: T&) {
    storage.push(x&)
}

func mutate<T>(x: mut T) {
    // ...
}

func inspect<T>(x: T) {
    // ...
}
```

---

## 7. No Constraints

Type parameters are unconstrained. There is no bound syntax (`T: Trait`), no `interface`/`impl` declaration, and no `where` clause.

```vertex
func f<T>(x: T) { }        // valid — T is bare
```

```vertex
func g<T: Ordered>(x: T) { }   // invalid — constraint syntax does not exist
```

---

## 8. Instantiation-Site Checking

A generic function or type is only checked once a concrete type is substituted in. Errors are reported at the point of instantiation, not at the generic declaration.

```vertex
struct Widget {
    id: int32
}

func largest<T>(list: [T]) -> T {
    var largest = list[0]
    for item in list {
        if item > largest { largest = item }   // requires `>` on T
    }
    return largest
}

largest([1, 2, 3])                 // OK — int32 supports `>`
largest([Widget{id: 1}])           // error: `>` not defined for Widget,
                                    // reported inside largest's body
                                    // at this instantiation
```

---

## 9. Generic Methods on Non-Generic Types

A method itself may introduce its own type parameter, independent of the type's own parameters.

```vertex
struct Container<T> {
    items: [T] = []
}

func (c: Container<T>) map<U>(f: func(T) -> U) -> Container<U> {
    var out: Container<U> = Container<U>{}
    for item in c.items {
        out.items.push(f(item))
    }
    return out
}
```