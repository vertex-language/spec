package structs_test
build test

struct Point {
    x: int32
    y: int32
}

func test_var_struct_field_mutation() test -> Expected(int32, "10") {
    var q = Point{x: 3, y: 4}
    q.y = 10
    return q.y
}

func test_var_struct_other_field_unaffected() test -> Expected(int32, "3") {
    var q = Point{x: 3, y: 4}
    q.y = 10
    return q.x
}

func test_struct_copy_mutation_does_not_affect_original() test -> Expected(bool, "1") {
    var q = Point{x: 3, y: 4}
    var q2 = q
    q2.x = 99
    return q.x == 3
}