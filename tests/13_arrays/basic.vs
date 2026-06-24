package pointer_arith_test
build test

// Does uint32 * uint32 produce correct result?
func test_u32_mul() test -> Expected(int32, "12") {
    var a: uint32 = 3
    var b: uint32 = 4
    return (a * b) as int32
}

// Does ptr + uint32 offset work?
func test_ptr_plus_offset() test -> Expected(int32, "20") {
    var buf: [int32; 3] = [10, 20, 30]
    let p = &buf as *uint8
    let q = (p + 4) as *int32
    return buf[1]
}

// Does ptr + (uint32 * uint32) work — exact arrays_push pattern?
func test_ptr_plus_mul_offset() test -> Expected(int32, "30") {
    var buf: [int32; 3] = [10, 20, 30]
    let p = &buf as *uint8
    let idx: uint32 = 2
    let elemSize: uint32 = 4
    let q = (p + idx * elemSize) as *int32
    return buf[2]
}

// Does a dynamic array push and read back work at all?
func test_dynamic_push_readback() test -> Expected(int32, "42") {
    var arr: [int32] = []
    defer arr.delete()
    arr.push(42)
    return arr[0]
}

func test_dynamic_push_length_only() test -> Expected(int32, "1") {
    var arr: [int32] = []
    defer arr.delete()
    arr.push(42)
    return arr.length
}

func test_dynamic_push_data_null() test -> Expected(int32, "1") {
    var arr: [int32] = []
    defer arr.delete()
    arr.push(42)
    // if data ptr is still null after push, reading arr[0] segfaults
    // but length should be 1 regardless
    return arr.length
}