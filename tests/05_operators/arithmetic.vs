package operators_test
build test

func test_add() test -> Expected(int32, "15") {
    return 10 + 5
}

func test_sub() test -> Expected(int32, "5") {
    return 10 - 5
}

func test_mul() test -> Expected(int32, "50") {
    return 10 * 5
}

func test_div() test -> Expected(int32, "3") {
    return 15 / 5
}

func test_mod() test -> Expected(int32, "2") {
    return 17 % 5
}

func test_negate() test -> Expected(int32, "-10") {
    let a: int32 = 10
    return -a
}

func test_precedence_mul_before_add() test -> Expected(int32, "14") {
    return 2 + 3 * 4    // 2 + 12, not 5 * 4
}

func test_precedence_parens_override() test -> Expected(int32, "20") {
    return (2 + 3) * 4
}

func test_compound_sub() test -> Expected(int32, "5") {
    var a: int32 = 10
    a -= 5
    return a
}

func test_compound_div() test -> Expected(int32, "2") {
    var a: int32 = 10
    a /= 5
    return a
}

func test_compound_mod() test -> Expected(int32, "1") {
    var a: int32 = 11
    a %= 5
    return a
}