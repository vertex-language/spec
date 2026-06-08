package control_flow_test
build test

func test_for_half_open_sum() test -> Expected(int32, "10") {
    var sum: int32 = 0
    for i in 0..<5 {
        sum += i    // 0+1+2+3+4 = 10
    }
    return sum
}

func test_for_closed_sum() test -> Expected(int32, "15") {
    var sum: int32 = 0
    for i in 0...5 {
        sum += i    // 0+1+2+3+4+5 = 15
    }
    return sum
}

func test_for_half_open_iteration_count() test -> Expected(int32, "5") {
    var count: int32 = 0
    for i in 0..<5 {
        count += 1
    }
    return count
}

func test_for_closed_iteration_count() test -> Expected(int32, "6") {
    var count: int32 = 0
    for i in 0...5 {
        count += 1
    }
    return count
}

func test_for_range_last_value() test -> Expected(int32, "4") {
    var last: int32 = 0
    for i in 0..<5 {
        last = i
    }
    return last
}

func test_for_range_closed_last_value() test -> Expected(int32, "5") {
    var last: int32 = 0
    for i in 0...5 {
        last = i
    }
    return last
}