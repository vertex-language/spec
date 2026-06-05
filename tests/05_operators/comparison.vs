package operators_test
build test

func test_eq_true() test -> Expected("1") {
    return 5 == 5
}

func test_eq_false() test -> Expected("0") {
    return 5 == 6
}

func test_ne_true() test -> Expected("1") {
    return 5 != 6
}

func test_gt_true() test -> Expected("1") {
    return 6 > 5
}

func test_gt_false() test -> Expected("0") {
    return 5 > 6
}

func test_lt_true() test -> Expected("1") {
    return 4 < 5
}

func test_gte_equal() test -> Expected("1") {
    return 5 >= 5
}

func test_gte_false() test -> Expected("0") {
    return 4 >= 5
}

func test_lte_less() test -> Expected("1") {
    return 4 <= 5
}

func test_lte_false() test -> Expected("0") {
    return 6 <= 5
}