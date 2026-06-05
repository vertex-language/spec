package types_test
build test

func test_uint8_max() test -> Expected("255") {
    let x: uint8 = 255
    return x
}

func test_uint16_max() test -> Expected("65535") {
    let x: uint16 = 65535
    return x
}

func test_uint32_val() test -> Expected("100") {
    let x: uint32 = 100
    return x
}

func test_uint64_val() test -> Expected("100") {
    let x: uint64 = 100
    return x
}

func test_uint_alias_is_uint32() test -> Expected("77") {
    let x: uint = 77
    return x
}