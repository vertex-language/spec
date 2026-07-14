package arrays_test
build test

func test_fixed_array_declaration_zeroed() test -> Expected(int32, "0") {
    var nums: [16]int32
    return nums[0]
}

func test_fixed_array_literal_init() test -> Expected(int32, "20") {
    var coords: [3]int32 = [10, 20, 30]
    return coords[1]
}

func test_fixed_array_inferred_literal() test -> Expected(int32, "2") {
    let nums = [1, 2, 3]
    return nums[1]
}

func test_fixed_array_annotated_literal() test -> Expected(int32, "255") {
    let flags: [3]uint8 = [0xFF, 0x00, 0xAB]
    return int32(flags[0])
}

func test_fixed_array_multiline_literal() test -> Expected(int32, "170") {
    let bytes: [3]uint8 = [
        0xFF,
        0x00,
        0xAB,
    ]
    return int32(bytes[2])
}

func test_fixed_array_read() test -> Expected(int32, "10") {
    var buf: [1024]uint8
    buf[0] = 10
    return int32(buf[0])
}

func test_fixed_array_write() test -> Expected(int32, "255") {
    var buf: [1024]uint8
    buf[0] = 255
    return int32(buf[0])
}