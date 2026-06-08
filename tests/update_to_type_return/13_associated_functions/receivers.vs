package associated_functions_test
build test

struct Counter {
    value: int32
}

// value receiver — copy, no mutation visible to caller
func (c: Counter) getValue() -> int32 {
    return c.value
}

// pointer receivers — mutate caller's binding
func (c: *Counter) increment() {
    c.value += 1
}

func (c: *Counter) add(n: int32) {
    c.value += n
}

func (c: *Counter) reset() {
    c.value = 0
}

func test_value_receiver_reads_field() test -> Expected("10") {
    let c = Counter{value: 10}
    return c.getValue()
}

func test_pointer_receiver_increments() test -> Expected("6") {
    var c = Counter{value: 5}
    c.increment()
    return c.value
}

func test_pointer_receiver_add() test -> Expected("15") {
    var c = Counter{value: 5}
    c.add(n: 10)
    return c.value
}

func test_pointer_receiver_reset() test -> Expected("0") {
    var c = Counter{value: 42}
    c.reset()
    return c.value
}

func test_value_receiver_does_not_mutate() test -> Expected("10") {
    var c = Counter{value: 10}
    let _ = c.getValue()    // value receiver, copy only
    return c.value           // original untouched
}

func test_chained_mutations() test -> Expected("7") {
    var c = Counter{value: 0}
    c.add(n: 10)
    c.add(n: 3)
    c.reset()
    c.add(n: 7)
    return c.value
}