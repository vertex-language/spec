package operators_test
build test

func test_ternary_true_branch() test -> Expected("10") {
    let x: int32 = 5 > 3 ? 10 : 20
    return x
}

func test_ternary_false_branch() test -> Expected("20") {
    let x: int32 = 3 > 5 ? 10 : 20
    return x
}

func test_ternary_select_max() test -> Expected("20") {
    let a: int32 = 10
    let b: int32 = 20
    return a > b ? a : b
}

func test_ternary_select_min() test -> Expected("10") {
    let a: int32 = 10
    let b: int32 = 20
    return a < b ? a : b
}

func test_ternary_nested() test -> Expected("2") {
    let x: int32 = 5
    let result: int32 = x < 0 ? 0 : x < 10 ? 2 : 3
    return result
}