package tuples_test
build test

func divmod(a: int32, b: int32) -> (int32, int32) {
    return (a / b, a % b)
}

func minMax(a: int32, b: int32) -> (min: int32, max: int32) {
    return a < b ? (a, b) : (b, a)
}

func test_tuple_destructure_first() test -> Expected(int32, "3") {
    let (q, r) = divmod(10, 3)
    return q
}

func test_tuple_destructure_second() test -> Expected(int32, "1") {
    let (q, r) = divmod(10, 3)
    return r
}

func test_tuple_labeled_min() test -> Expected(int32, "4") {
    let (lo, hi) = minMax(7, 4)
    return lo
}

func test_tuple_labeled_max() test -> Expected(int32, "7") {
    let (lo, hi) = minMax(7, 4)
    return hi
}

func test_tuple_inline_literal() test -> Expected(int32, "10") {
    let (a, b): (int32, int32) = (10, 20)
    return a
}

func test_tuple_equality_true() test -> Expected(bool, "1") {
    let a = (1, 2)
    let b = (1, 2)
    return a == b
}

func test_tuple_equality_false() test -> Expected(bool, "0") {
    let a = (1, 2)
    let b = (1, 3)
    return a == b
}