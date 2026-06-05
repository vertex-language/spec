package operators_test
build test

func test_overflow_add_wraps() test -> Expected("-2147483648") {
    let a: int32 = 2147483647    // INT32_MAX
    return a &+ 1                // wraps to INT32_MIN
}

func test_overflow_sub_wraps() test -> Expected("2147483647") {
    let a: int32 = -2147483648   // INT32_MIN
    return a &- 1                // wraps to INT32_MAX
}

func test_overflow_mul_wraps() test -> Expected("-2") {
    let a: int32 = 2147483647
    return a &* 2                // 2^32 - 2 as signed = -2
}

func test_overflow_add_no_trap() test {
    let a: int32 = 2147483647
    let b: int32 = a &+ 1       // must not trap
}