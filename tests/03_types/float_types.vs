package types_test
build test

func test_float32_val() test -> Expected(float32, "3.14") {
    let x: float32 = 3.14
    return x
}

func test_float64_val() test -> Expected(float64, "3.14159") {
    let x: float64 = 3.14159265358979
    return x
}

func test_float32_zero() test -> Expected(float32, "0") {
    let x: float32 = 0.0
    return x
}