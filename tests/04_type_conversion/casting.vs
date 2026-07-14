package type_conversion_test
build test

func test_cast_widen_int32_to_int64() test -> Expected(int32, "42") {
    let small: int32 = 42
    let wide = small as int64
    return int32(wide)
}

func test_cast_signed_to_unsigned() test -> Expected(uint32, "42") {
    let small: int32 = 42
    let big = small as uint64
    return uint32(big)
}

func test_cast_float_to_int32() test -> Expected(int32, "3") {
    let f: float64 = 3.99
    let i = f as int32
    return i
}

func test_cast_in_arithmetic_expression() test -> Expected(float32, "3.500000") {
    let count: int32 = 7
    let total: int32 = 2
    let ratio = count as float64 / total as float64
    return float32(ratio)
}

func test_chained_cast() test -> Expected(int32, "5") {
    let value: int32 = 5
    let x = value as int32 as int64
    return int32(x)
}

func test_cast_bool_condition_unaffected() test -> Expected(bool, "1") {
    let a: int32 = 10
    let b: int64 = a as int64
    return b == 10
}