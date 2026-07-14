package operators_test
build test

func test_add() test -> Expected(int32, "7") {
    let a: int32 = 3
    let b: int32 = 4
    return a + b
}

func test_sub() test -> Expected(int32, "-1") {
    let a: int32 = 3
    let b: int32 = 4
    return a - b
}

func test_mul() test -> Expected(int32, "12") {
    let a: int32 = 3
    let b: int32 = 4
    return a * b
}

func test_div() test -> Expected(int32, "2") {
    let a: int32 = 9
    let b: int32 = 4
    return a / b
}

func test_mod() test -> Expected(int32, "1") {
    let a: int32 = 9
    let b: int32 = 4
    return a % b
}

func test_unary_minus() test -> Expected(int32, "-9") {
    let a: int32 = 9
    return -a
}

func test_float_div() test -> Expected(float32, "2.250000") {
    let a: float32 = 9.0
    let b: float32 = 4.0
    return a / b
}