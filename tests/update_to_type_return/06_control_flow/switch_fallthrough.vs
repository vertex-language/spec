package control_flow_test
build test

func test_fallthrough_continues_to_next_case() test -> Expected("10") {
    var x: int32 = 0
    switch 0 {
    case 0:
        x = 5
        fallthrough
    case 1:
        x += 5    // reached via fallthrough: x becomes 10
    default:
        x = 99
    }
    return x
}

func test_no_implicit_fallthrough() test -> Expected("5") {
    var x: int32 = 0
    switch 0 {
    case 0:
        x = 5     // stops here without fallthrough
    case 1:
        x = 10
    default:
        x = 99
    }
    return x
}

func test_fallthrough_skips_condition() test -> Expected("1") {
    // fallthrough transfers unconditionally — case 1 runs even though x != 1
    var hit: int32 = 0
    switch 0 {
    case 0:
        hit = 0
        fallthrough
    case 1:
        hit = 1
    default:
        hit = 99
    }
    return hit
}