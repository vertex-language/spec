package operators_test
build test

func test_not() test -> Expected(bool, "0") {
    let a: bool = true
    return !a
}

func test_and_true() test -> Expected(bool, "1") {
    let a: bool = true
    let b: bool = true
    return a && b
}

func test_and_false() test -> Expected(bool, "0") {
    let a: bool = true
    let b: bool = false
    return a && b
}

func test_or_true() test -> Expected(bool, "1") {
    let a: bool = false
    let b: bool = true
    return a || b
}

func test_or_false() test -> Expected(bool, "0") {
    let a: bool = false
    let b: bool = false
    return a || b
}

func test_short_circuit_and() test -> Expected(bool, "0") {
    var called = false
    let sideEffect = func() -> bool {
        called = true
        return true
    }
    let result = false && sideEffect()
    return called
}