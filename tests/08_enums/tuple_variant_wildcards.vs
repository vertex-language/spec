package enums_test
build test

enum Shape {
    Point,
    Circle(float32),
    Rectangle(float32, float32),
    Color(uint8, uint8, uint8),
}

func test_wildcard_ignores_second_field() test -> Expected(float32, "3.000000") {
    let s = Shape.Rectangle(3.0, 4.0)
    var result: float32 = 0.0
    switch s {
    case .Point:
    case .Circle(r):
    case .Rectangle(w, _):
        result = w
    case .Color(r, g, b):
    }
    return result
}

func test_wildcard_ignores_two_of_three_fields() test -> Expected(int32, "255") {
    let s = Shape.Color(255, 0, 0)
    var result: int32 = 0
    switch s {
    case .Point:
    case .Circle(r):
    case .Rectangle(w, h):
    case .Color(r, _, _):
        result = int32(r)
    }
    return result
}

func test_wildcard_with_default_fallback() test -> Expected(bool, "1") {
    let s = Shape.Point
    var matched = false
    switch s {
    case .Rectangle(w, _):
        matched = false
    case .Color(r, _, _):
        matched = false
    default:
        matched = true
    }
    return matched
}