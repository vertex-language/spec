package structs_test
build test

struct Vec2 {
    x: float32
    y: float32
}

struct Line {
    start: Vec2
    end:   Vec2
}

func test_nested_start_x() test -> Expected(float32, "0.000000") {
    let l = Line{
        start: Vec2{x: 0.0, y: 0.0},
        end:   Vec2{x: 10.0, y: 5.0},
    }
    return l.start.x
}

func test_nested_end_x() test -> Expected(float32, "10.000000") {
    let l = Line{
        start: Vec2{x: 0.0, y: 0.0},
        end:   Vec2{x: 10.0, y: 5.0},
    }
    return l.end.x
}

func test_nested_end_y() test -> Expected(float32, "5.000000") {
    let l = Line{
        start: Vec2{x: 0.0, y: 0.0},
        end:   Vec2{x: 10.0, y: 5.0},
    }
    return l.end.y
}

func test_nested_field_mutation() test -> Expected(float32, "7.000000") {
    var l = Line{
        start: Vec2{x: 0.0, y: 0.0},
        end:   Vec2{x: 10.0, y: 5.0},
    }
    l.start.x = 7.0
    return l.start.x
}