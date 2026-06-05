package type_conversion_test
build test

func test_int_to_float() test -> Expected("42.000000") {
    let i: int32 = 42
    let f: float = float(i)
    return f
}

func test_float_to_int_truncate_down() test -> Expected("3") {
    let f: float = 3.99
    let i: int32 = int32(f)
    return i
}

func test_float_to_int_truncate_neg() test -> Expected("-3") {
    let f: float = -3.99
    let i: int32 = int32(f)
    return i
}

func test_int32_to_int64_widens() test -> Expected("2147483647") {
    let i: int32 = 2147483647
    let l: int64 = int64(i)
    return l
}

func test_int8_narrowing_wraps() test -> Expected("-1") {
    let i: int32 = 255
    let b: int8 = int8(i)    // 0xFF as signed int8 = -1
    return b
}

func test_uint8_to_int32() test -> Expected("200") {
    let u: uint8 = 200
    let i: int32 = int32(u)
    return i
}