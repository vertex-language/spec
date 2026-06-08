package type_conversion_test
build test

func test_int_to_float32() test -> Expected(float32, "42.000000") {
    let i: int32 = 42
    let f: float32 = float32(i)
    return f
}

func test_float32_to_int_truncate_down() test -> Expected(int32, "3") {
    let f: float32 = 3.99
    let i: int32 = int32(f)
    return i
}

func test_float32_to_int_truncate_neg() test -> Expected(int32, "-3") {
    let f: float32 = -3.99
    let i: int32 = int32(f)
    return i
}

func test_int32_to_int64_widens() test -> Expected(int64, "2147483647") {
    let i: int32 = 2147483647
    let l: int64 = int64(i)
    return l
}

func test_int8_narrowing_wraps() test -> Expected(int8, "-1") {
    let i: int32 = 255
    let b: int8 = int8(i)    // 0xFF as signed int8 = -1
    return b
}

func test_uint8_to_int32() test -> Expected(int32, "200") {
    let u: uint8 = 200
    let i: int32 = int32(u)
    return i
}