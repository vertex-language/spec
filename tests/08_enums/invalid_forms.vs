package enums_test
build test

enum Direction {
    North,
    South,
    East,
    West,
}

func test_switch_missing_case_no_default() test -> Expected(error) {
    let d = Direction.North
    switch d {
    case .North:
    case .South:
    case .East:
    // missing .West and no default — non-exhaustive switch
    }
}

enum Shape {
    Point,
    Circle(float32),
}

func test_tuple_pattern_wrong_arity() test -> Expected(error) {
    let s = Shape.Circle(1.5)
    switch s {
    case .Point:
    case .Circle(r, extra):
        // Circle only carries one field — binding two is an error
    }
}

func test_unit_variant_called_like_function() test -> Expected(error) {
    let d = Direction.North(5)
}