package operators_test
build test

func test_wrapping_add_no_overflow() test -> Expected(int32, "9") {
    let a: int8 = 4
    let b: int8 = 5
    let c = a &+ b
    return int32(c)
}

func test_wrapping_add_overflows_int8() test -> Expected(int32, "-128") {
    let a: int8 = 127
    let b: int8 = 1
    let c = a &+ b
    return int32(c)
}

func test_wrapping_sub_overflows_uint8() test -> Expected(int32, "255") {
    let a: uint8 = 0
    let b: uint8 = 1
    let c = a &- b
    return int32(c)
}

func test_wrapping_mul_overflows_uint8() test -> Expected(int32, "0") {
    let a: uint8 = 128
    let b: uint8 = 2
    let c = a &* b
    return int32(c)
}