package types_test
build test

func test_float_val() test -> Expected("3.140000") {
    let x: float = 3.14
    return x
}

func test_float64_val() test -> Expected("3.141593") {
    let x: float64 = 3.14159265358979
    return x
}

func test_float_zero() test -> Expected("0.000000") {
    let x: float = 0.0
    return x
}