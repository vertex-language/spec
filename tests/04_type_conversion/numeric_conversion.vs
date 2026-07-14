package type_conversion_test
build test

func test_int_to_float32() test -> Expected(float32, "42.000000") {
    let i: int = 42
    let f: float32 = float32(i)
    return f
}

func test_float_to_int_truncates() test -> Expected(int32, "3") {
    let i2: int = int(3.99)
    return int32(i2)
}

func test_float_to_int_truncates_no_round() test -> Expected(int32, "3") {
    let i2: int = int(3.00001)
    return int32(i2)
}

func test_int_to_int8_narrowing() test -> Expected(int32, "42") {
    let i: int = 42
    let b: int8 = int8(i)
    return int32(b)
}

func test_negative_float_to_int_truncates_toward_zero() test -> Expected(int32, "-3") {
    let i: int = int(-3.99)
    return int32(i)
}