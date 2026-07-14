package control_flow_test
build test

func test_switch_matches_case_0() test -> Expected(int32, "0") {
    let x: int32 = 0
    var result: int32 = -1
    switch x {
    case 0:
        result = 0
    case 1:
        result = 1
    default:
        result = -1
    }
    return result
}

func test_switch_matches_case_1() test -> Expected(int32, "1") {
    let x: int32 = 1
    var result: int32 = -1
    switch x {
    case 0:
        result = 0
    case 1:
        result = 1
    default:
        result = -1
    }
    return result
}

func test_switch_falls_to_default() test -> Expected(int32, "-1") {
    let x: int32 = 9
    var result: int32 = -1
    switch x {
    case 0:
        result = 0
    case 1:
        result = 1
    default:
        result = -1
    }
    return result
}

func test_switch_multi_value_case() test -> Expected(bool, "1") {
    let x: int32 = 2
    var matched = false
    switch x {
    case 1, 2:
        matched = true
    default:
        matched = false
    }
    return matched
}

func test_switch_string_case() test -> Expected(int32, "1") {
    let s: string = "hello"
    var result: int32 = -1
    switch s {
    case "hello":
        result = 1
    case "world":
        result = 2
    default:
        result = -1
    }
    return result
}