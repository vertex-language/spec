package structs_test
build test

struct Point {
    x: int32
    y: int32
}

struct Rect {
    width:  int32
    height: int32
}

func test_struct_field_x() test -> Expected(int32, "3") {
    let p = Point{x: 3, y: 4}
    return p.x
}

func test_struct_field_y() test -> Expected(int32, "4") {
    let p = Point{x: 3, y: 4}
    return p.y
}

func test_struct_copy_preserves_value() test -> Expected(int32, "3") {
    let p  = Point{x: 3, y: 4}
    let p2 = p
    return p2.x
}

func test_struct_var_field_write() test -> Expected(int32, "10") {
    var q = Point{x: 3, y: 4}
    q.y = 10
    return q.y
}

func test_struct_copy_independent() test -> Expected(int32, "4") {
    let p  = Point{x: 3, y: 4}
    var p2 = p
    p2.y = 99         // mutate the copy
    return p.y        // original unchanged
}

func test_struct_multiline_init() test -> Expected(int32, "10") {
    let r = Rect{
        width:  10,
        height: 20,
    }
    return r.width
}