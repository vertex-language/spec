package structs_test
build test

struct Point {
    x: int32
    y: int32
}

func test_let_struct_field_immutable() test -> Expected(error) {
    let p = Point{x: 3, y: 4}
    p.x = 5
}

func test_bad_field_name() test -> Expected(error) {
    let p = Point{x: 0, y: 0}
    let n = p.z
}

func test_missing_required_field() test -> Expected(error) {
    let p = Point{x: 3}
}

func test_wrong_field_type() test -> Expected(error) {
    let p = Point{x: "three", y: 4}
}