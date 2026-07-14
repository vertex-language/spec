package control_flow_test
build test

func test_for_range_count() test -> Expected(int32, "5") {
    var count: int32 = 0
    for i in 0..5 {
        count += 1
    }
    return count
}

func test_for_range_last_value_excluded() test -> Expected(int32, "4") {
    var last: int32 = -1
    for i in 0..5 {
        last = i
    }
    return last
}

func test_for_range_variable_bounds() test -> Expected(int32, "3") {
    let start: int32 = 2
    let end: int32 = 5
    var count: int32 = 0
    for i in start..end {
        count += 1
    }
    return count
}