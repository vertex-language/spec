package operators_test
build test

func test_plus_assign() test -> Expected(int32, "9") {
    var a: int32 = 4
    a += 5
    return a
}

func test_minus_assign() test -> Expected(int32, "-1") {
    var a: int32 = 4
    a -= 5
    return a
}

func test_star_assign() test -> Expected(int32, "20") {
    var a: int32 = 4
    a *= 5
    return a
}

func test_slash_assign() test -> Expected(int32, "2") {
    var a: int32 = 10
    a /= 5
    return a
}

func test_pct_assign() test -> Expected(int32, "1") {
    var a: int32 = 11
    a %= 5
    return a
}

func test_chained_compound_assign() test -> Expected(int32, "23") {
    var a: int32 = 4
    a += 5
    a *= 3
    a -= 4
    return a
}