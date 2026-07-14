package tuples_test
build test

func test_destructure_two_bindings() test -> Expected(int32, "3") {
    let t = (1, 2)
    let a, b = t
    return a + b
}

func test_destructure_first_binding() test -> Expected(int32, "1") {
    let t = (1, "a")
    let a, b = t
    return a
}

func test_destructure_second_binding() test -> Expected(string, "a") {
    let t = (1, "a")
    let a, b = t
    return b
}

func test_destructure_named_tuple_positional() test -> Expected(int32, "3") {
    let p: (x: int32, y: int32) = (x: 3, y: 4)
    let px, py = p
    return px
}

func test_named_tuple_field_access_preserves_names() test -> Expected(int32, "4") {
    let p: (x: int32, y: int32) = (x: 3, y: 4)
    return p.y
}