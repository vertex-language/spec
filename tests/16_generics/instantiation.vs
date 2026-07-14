package generics_test
build test

class Stack[T] {
    items: []T
}

func (s: mut Stack[T]) push(item: var T) {
    s.items.push(item.transfer())
}

func (s: mut Stack[T]) pop() -> (T, string) {
    if s.items.length == 0 {
        var zero: T
        return zero, "empty"
    }
    return s.items.pop(), ""
}

func (s: Stack[T]) init() {
    s.items = []
}

func test_explicit_instantiation_construction() test -> Expected(int32, "0") {
    var s = Stack[int32]()
    return s.items.length
}

func test_push_then_pop() test -> Expected(int32, "5") {
    var s = Stack[int32]()
    s.push(5)
    let v, err = s.pop()
    if err != "" {
        return -1
    }
    return v
}

func test_pop_empty_returns_error() test -> Expected(bool, "1") {
    var s = Stack[int32]()
    let v, err = s.pop()
    return err != ""
}

func min[T](a: T, b: T) -> T {
    if a < b { return a }
    return b
}

func test_inferred_instantiation_int() test -> Expected(int32, "3") {
    let x = min(3, 5)
    return x
}

func test_inferred_instantiation_float() test -> Expected(float64, "2.710000") {
    let y = min(3.14, 2.71)
    return y
}

func memAlloc[T](count: uint64) -> (typed_ptr T, string) {
    return new[T](count)
}