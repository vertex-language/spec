package classes_test
build test

class Point {
    x: int32
    y: int32
}

func (p: Point) init(x: int32, y: int32) {
    p.x = x
    p.y = y
}

func test_let_class_field_immutable() test -> Expected(error) {
    let p = Point(x: 3, y: 4)
    p.x = 5
}

func test_bad_field_name_on_class() test -> Expected(error, "no field 'z' on Point") {
    let p = Point(x: 0, y: 0)
    let n = p.z
}

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func test_struct_and_class_identity_never_unify() test -> Expected(error) {
    let w = Widget(id: 1)
    let p = Point(x: 1, y: 1)
    let same = w === p
}