package control_flow_test
build test

func test_for_array_sum() test -> Expected(int32, "6") {
    let nums = [1, 2, 3]
    var sum: int32 = 0
    for n in nums {
        sum += n
    }
    return sum
}

func test_for_array_count() test -> Expected(int32, "3") {
    let nums = [10, 20, 30]
    var count: int32 = 0
    for n in nums {
        count += 1
    }
    return count
}

func test_for_array_last_element() test -> Expected(int32, "30") {
    let nums = [10, 20, 30]
    var last: int32 = 0
    for n in nums {
        last = n
    }
    return last
}

func test_for_array_typed() test -> Expected(uint8, "255") {
    let bytes: [uint8] = [0x00, 0x7F, 0xFF]
    var last: uint8 = 0
    for b in bytes {
        last = b
    }
    return last
}