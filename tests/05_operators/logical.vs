package operators_test
build test

func test_not_true() test -> Expected("0") {
    return !true
}

func test_not_false() test -> Expected("1") {
    return !false
}

func test_and_tt() test -> Expected("1") {
    return true && true
}

func test_and_tf() test -> Expected("0") {
    return true && false
}

func test_or_tf() test -> Expected("1") {
    return true || false
}

func test_or_ff() test -> Expected("0") {
    return false || false
}

func test_short_circuit_and() test -> Expected("0") {
    let result = false && true
    return result
}

func test_short_circuit_or() test -> Expected("1") {
    let result = true || false
    return result
}