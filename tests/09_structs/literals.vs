package structs_test
build test

struct Point {
    x: int32
    y: int32
}

func test_struct_field_access() test -> Expected(int32, "3") {
    let p = Point{x: 3, y: 4}
    return p.x
}

func test_struct_field_access_second_field() test -> Expected(int32, "4") {
    let p = Point{x: 3, y: 4}
    return p.y
}

func test_struct_literal_multiline() test -> Expected(int32, "3") {
    let p = Point{
        x: 3,
        y: 4,
    }
    return p.x
}

func test_struct_copy_is_independent() test -> Expected(int32, "3") {
    let p = Point{x: 3, y: 4}
    let p2 = p
    return p2.x
}

func test_struct_bare_copy_leaves_original_usable() test -> Expected(bool, "1") {
    let p = Point{x: 3, y: 4}
    let p2 = p
    return p.x == p2.x
}