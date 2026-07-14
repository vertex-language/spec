package tuples_test
build test

func test_named_tuple_field_x() test -> Expected(int32, "1") {
    let t = (x: 1, y: "a")
    return t.x
}

func test_named_tuple_field_y() test -> Expected(string, "a") {
    let t = (x: 1, y: "a")
    return t.y
}

func test_named_tuple_typed_construction() test -> Expected(int32, "3") {
    let p: (x: int32, y: int32) = (x: 3, y: 4)
    return p.x
}

func test_named_tuple_typed_construction_second() test -> Expected(int32, "4") {
    let p: (x: int32, y: int32) = (x: 3, y: 4)
    return p.y
}