package tuples_test
build test

func test_tuple_destructure_first() test -> Expected("1") {
    let pair = (1, true)
    let (a, b) = pair
    return a
}

func test_tuple_destructure_second_bool() test -> Expected("1") {
    let pair = (1, true)
    let (a, b) = pair
    return b
}

func test_labeled_tuple_x() test -> Expected("10") {
    let point = (x: 10, y: 20)
    let (x, y) = point
    return x
}

func test_labeled_tuple_y() test -> Expected("20") {
    let point = (x: 10, y: 20)
    let (x, y) = point
    return y
}

func test_typed_destructure() test -> Expected("14") {
    let (x, y): (int32, int32) = (14, 17)
    return x
}

func test_tuple_equality() test -> Expected("1") {
    let a = (1, 2)
    let b = (1, 2)
    return a == b
}

func test_tuple_inequality() test -> Expected("1") {
    let a = (1, 2)
    let b = (1, 3)
    return a != b
}

func test_tuple_comparison_lt() test -> Expected("1") {
    let a = (1, 5)
    let b = (2, 0)
    return a < b    // first element 1 < 2
}