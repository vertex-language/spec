package types_test
build test

func test_byte_literal() test -> Expected(int32, "255") {
    let b: byte = 0xFF
    return int32(b)
}

func test_byte_to_uint8_no_cast() test -> Expected(int32, "10") {
    let b: byte = 10
    let b2: uint8 = b
    return int32(b2)
}

func test_uint8_to_byte_no_cast() test -> Expected(int32, "42") {
    let u: uint8 = 42
    let b: byte = u
    return int32(b)
}

func test_byte_array() test -> Expected(int32, "3") {
    let raw: []byte = [0xFF, 0x00, 0xAB]
    return int32(raw.length)
}

func test_byte_uint8_array_interchange() test -> Expected(int32, "0") {
    let raw: []byte = [0xFF, 0x00, 0xAB]
    let same: []uint8 = raw
    return int32(same[1])
}