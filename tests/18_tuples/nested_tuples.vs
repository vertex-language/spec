package tuples_test
build test

func test_nested_tuple_outer_access() test -> Expected(int32, "1") {
    let t: ((int32, int32), string) = ((1, 2), "origin")
    let inner = t.0.0
    return inner
}

func test_nested_tuple_second_inner_field() test -> Expected(int32, "2") {
    let t: ((int32, int32), string) = ((1, 2), "origin")
    return t.0.1
}

func test_nested_tuple_outer_string_field() test -> Expected(string, "origin") {
    let t: ((int32, int32), string) = ((1, 2), "origin")
    return t.1
}