package operators_test
build test

func test_bitwise_not() test -> Expected("-6") {
    let a: int32 = 5    // ~5 = -6 in two's complement
    return ~a
}

func test_bitwise_and() test -> Expected("10") {
    let a: int32 = 15   // 0b1111
    let b: int32 = 10   // 0b1010
    return a & b        // 0b1010 = 10
}

func test_bitwise_or() test -> Expected("15") {
    let a: int32 = 12   // 0b1100
    let b: int32 = 3    // 0b0011
    return a | b        // 0b1111 = 15
}

func test_bitwise_xor() test -> Expected("6") {
    let a: int32 = 5    // 0b0101
    let b: int32 = 3    // 0b0011
    return a ^ b        // 0b0110 = 6
}

func test_left_shift() test -> Expected("20") {
    let a: int32 = 5
    return a << 2       // 5 * 4 = 20
}

func test_right_shift() test -> Expected("2") {
    let a: int32 = 8
    return a >> 2       // 8 / 4 = 2
}

func test_shift_precedence_over_add() test -> Expected("10") {
    return 2 + 1 << 3   // 2 + 8 = 10  (shift is highest)
}