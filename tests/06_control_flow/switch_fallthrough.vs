package control_flow_test
build test

func test_fallthrough_runs_next_case() test -> Expected(int32, "2") {
    let x: int32 = 0
    var count: int32 = 0
    switch x {
    case 0:
        count += 1
        fallthrough
    case 1:
        count += 1
    default:
        count += 100
    }
    return count
}

func test_no_fallthrough_stops_after_case() test -> Expected(int32, "1") {
    let x: int32 = 0
    var count: int32 = 0
    switch x {
    case 0:
        count += 1
    case 1:
        count += 1
    default:
        count += 100
    }
    return count
}