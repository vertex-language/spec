package structs_test
build test

struct Point {
    x: int32
    y: int32
}

struct Line {
    start: Point
    end:   Point
}

func test_nested_struct_field_access() test -> Expected(int32, "0") {
    let l = Line{
        start: Point{x: 0, y: 0},
        end:   Point{x: 10, y: 10},
    }
    return l.start.x
}

func test_nested_struct_deep_field_access() test -> Expected(int32, "10") {
    let l = Line{
        start: Point{x: 0, y: 0},
        end:   Point{x: 10, y: 10},
    }
    return l.end.y
}

func test_nested_struct_mutation() test -> Expected(int32, "99") {
    var l = Line{
        start: Point{x: 0, y: 0},
        end:   Point{x: 10, y: 10},
    }
    l.start.x = 99
    return l.start.x
}

func test_nested_struct_mutation_does_not_leak() test -> Expected(int32, "10") {
    var l = Line{
        start: Point{x: 0, y: 0},
        end:   Point{x: 10, y: 10},
    }
    l.start.x = 99
    return l.end.x
}