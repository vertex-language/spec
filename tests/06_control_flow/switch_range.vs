package control_flow_test
build test

func test_switch_range_first_bucket() test -> Expected(int32, "1") {
    let code: int32 = 50
    var result: int32 = -1
    switch code {
    case 0..100:
        result = 1
    case 100..200:
        result = 2
    default:
        result = -1
    }
    return result
}

func test_switch_range_second_bucket() test -> Expected(int32, "2") {
    let code: int32 = 150
    var result: int32 = -1
    switch code {
    case 0..100:
        result = 1
    case 100..200:
        result = 2
    default:
        result = -1
    }
    return result
}

func test_switch_range_boundary_exclusive() test -> Expected(int32, "2") {
    // ranges are always exclusive (foundation.md §13), so 100 falls
    // into the second bucket, not the first
    let code: int32 = 100
    var result: int32 = -1
    switch code {
    case 0..100:
        result = 1
    case 100..200:
        result = 2
    default:
        result = -1
    }
    return result
}