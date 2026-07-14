package operators_test
build test

func test_bitwise_not() test -> Expected(int32, "-1") {
    let a: int32 = 0
    return ~a
}

func test_bitwise_and() test -> Expected(int32, "8") {
    let a: int32 = 12
    let b: int32 = 10
    return a & b
}

func test_bitwise_or() test -> Expected(int32, "14") {
    let a: int32 = 12
    let b: int32 = 10
    return a | b
}

func test_bitwise_xor() test -> Expected(int32, "6") {
    let a: int32 = 12
    let b: int32 = 10
    return a ^ b
}

func test_shift_left() test -> Expected(int32, "16") {
    let a: int32 = 1
    return a << 4
}

func test_shift_right() test -> Expected(int32, "1") {
    let a: int32 = 16
    return a >> 4
}