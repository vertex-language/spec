package tuples_test
build test

func test_tuple_literal_positional_first() test -> Expected(int32, "1") {
    let t = (1, "a")
    return t.0
}

func test_tuple_literal_positional_second() test -> Expected(string, "a") {
    let t = (1, "a")
    return t.1
}

func test_tuple_two_int_literal() test -> Expected(int32, "2") {
    let pair = (1, 2)
    return pair.1
}

func test_single_element_tuple_requires_trailing_comma() test -> Expected(int32, "1") {
    let single = (1,)
    return single.0
}