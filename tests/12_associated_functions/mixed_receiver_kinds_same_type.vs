package associated_functions_test
build test

struct Counter {
    value: int32
}

func (c: Counter) peek() -> int32 {
    return c.value
}

func (c: mut Counter) bump() {
    c.value += 1
}

func test_mixed_shared_and_mut_on_same_type() test -> Expected(int32, "6") {
    var c = Counter{value: 5}
    c.bump()
    return c.peek()
}

func test_mixed_multiple_bumps_then_peek() test -> Expected(int32, "8") {
    var c = Counter{value: 5}
    c.bump()
    c.bump()
    c.bump()
    return c.peek()
}