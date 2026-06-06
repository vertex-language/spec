package control_flow_test
build test

func test_switch_matches_zero() test -> Expected("zero") {
    let x: int32 = 0
    switch x {
    case 0:
        return "zero"
    case 1:
        return "one"
    default:
        return "other"
    }
}

func test_switch_matches_one() test -> Expected("one") {
    let x: int32 = 1
    switch x {
    case 0:
        return "zero"
    case 1:
        return "one"
    default:
        return "other"
    }
}

func test_switch_hits_default() test -> Expected("other") {
    let x: int32 = 99
    switch x {
    case 0:
        return "zero"
    case 1:
        return "one"
    default:
        return "other"
    }
}

func test_switch_multi_value_first() test -> Expected("one or two") {
    let x: int32 = 1
    switch x {
    case 0:
        return "zero"
    case 1, 2:
        return "one or two"
    default:
        return "other"
    }
}

func test_switch_multi_value_second() test -> Expected("one or two") {
    let x: int32 = 2
    switch x {
    case 0:
        return "zero"
    case 1, 2:
        return "one or two"
    default:
        return "other"
    }
}

func test_switch_break_early() test -> Expected("5") {
    var x: int32 = 0
    switch 0 {
    case 0:
        x = 5
        break
    default:
        x = 99
    }
    return x
}