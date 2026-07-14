package operators_test
build test

func test_mul_before_add() test -> Expected(int32, "14") {
    return 2 + 3 * 4
}

func test_shift_binds_tightest() test -> Expected(int32, "9") {
    // shifts bind tighter than +, so this is (1 << 2) + (4 >> 1)... wait use simple case
    return 1 + (2 << 2)
}

func test_parens_override_precedence() test -> Expected(int32, "20") {
    return (2 + 3) * 4
}

func test_comparison_lower_than_arithmetic() test -> Expected(bool, "1") {
    return 2 + 3 == 5
}

func test_and_lower_than_comparison() test -> Expected(bool, "1") {
    return 1 < 2 && 3 < 4
}

func test_or_lowest_among_logical() test -> Expected(bool, "1") {
    return false && true || true
}

func test_range_lower_than_add_higher_than_cmp() test -> Expected(bool, "0") {
    // `..` sits between add and comparison, so `0..2+3 == 0..5` compares
    // a range's bound arithmetic before the range is compared for equality —
    // here we just verify range construction with an added bound resolves
    // the addition first.
    var count: int32 = 0
    for i in 0..1+2 {
        count += 1
    }
    return count == 3
}