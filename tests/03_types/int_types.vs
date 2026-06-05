package types_test
build test

func test_int8_max() test -> Expected("127") {
    let x: int8 = 127
    return x
}

func test_int8_min() test -> Expected("-128") {
    let x: int8 = -128
    return x
}

func test_int16_max() test -> Expected("32767") {
    let x: int16 = 32767
    return x
}

func test_int32_val() test -> Expected("100") {
    let x: int32 = 100
    return x
}

func test_int64_val() test -> Expected("9223372036854775807") {
    let x: int64 = 9223372036854775807
    return x
}

func test_int_alias_is_int32() test -> Expected("55") {
    let x: int = 55
    return x
}