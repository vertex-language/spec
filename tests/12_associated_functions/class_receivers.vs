package associated_functions_test
build test

class Counter {
    value: int32
}

// value receiver — copy, no mutation visible to caller
func (c: Counter) getValue() -> int32 {
    return c.value
}

// pointer receivers — mutate caller's binding
func (c: Counter) increment() {
    c.value += 1
}

func (c: Counter) add(n: int32) {
    c.value += n
}

func (c: Counter) reset() {
    c.value = 0
}

func test_value_receiver_reads_field() test -> Expected(int32, "10") {
    let c = Counter{value: 10}
    defer c.delete()
    return c.getValue()
}

func test_pointer_receiver_increments() test -> Expected(int32, "6") {
    var c = Counter{value: 5}
    defer c.delete()
    c.increment()
    return c.value
}

func test_pointer_receiver_add() test -> Expected(int32, "15") {
    var c = Counter{value: 5}
    defer c.delete()
    c.add(n: 10)
    return c.value
}

func test_pointer_receiver_reset() test -> Expected(int32, "0") {
    var c = Counter{value: 42}
    defer c.delete()
    c.reset()
    return c.value
}

func test_value_receiver_does_not_mutate() test -> Expected(int32, "10") {
    var c = Counter{value: 10}
    defer c.delete()
    c.getValue()        // value receiver — exercises the copy, discards result
    return c.value      // original untouched
}

func test_chained_mutations() test -> Expected(int32, "7") {
    var c = Counter{value: 0}
    defer c.delete()
    c.add(n: 10)
    c.add(n: 3)
    c.reset()
    c.add(n: 7)
    return c.value
}