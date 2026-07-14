package enums_test
build test

enum Shape {
    Point,
    Circle(float32),
    Rectangle(float32, float32),
    Color(uint8, uint8, uint8),
}

func test_tuple_variant_construct_and_match() test -> Expected(float32, "1.500000") {
    let s = Shape.Circle(1.5)
    var result: float32 = 0.0
    switch s {
    case .Point:
        result = 0.0
    case .Circle(r):
        result = r
    case .Rectangle(w, h):
        result = 0.0
    case .Color(r, g, b):
        result = 0.0
    }
    return result
}

func test_tuple_variant_two_fields() test -> Expected(float32, "12.000000") {
    let s = Shape.Rectangle(3.0, 4.0)
    var result: float32 = 0.0
    switch s {
    case .Point:
    case .Circle(r):
    case .Rectangle(w, h):
        result = w * h
    case .Color(r, g, b):
    }
    return result
}

func test_tuple_variant_three_fields() test -> Expected(int32, "765") {
    let s = Shape.Color(255, 255, 255)
    var result: int32 = 0
    switch s {
    case .Point:
    case .Circle(r):
    case .Rectangle(w, h):
    case .Color(r, g, b):
        result = int32(r) + int32(g) + int32(b)
    }
    return result
}

func test_tuple_variant_no_payload() test -> Expected(bool, "1") {
    let s = Shape.Point
    var matched = false
    switch s {
    case .Point:
        matched = true
    case .Circle(r):
    case .Rectangle(w, h):
    case .Color(r, g, b):
    }
    return matched
}

enum Result {
    Ok(int32),
    Err(string),
}

func test_result_ok_variant() test -> Expected(int32, "42") {
    let r = Result.Ok(42)
    var value: int32 = -1
    switch r {
    case .Ok(v):
        value = v
    case .Err(e):
        value = -1
    }
    return value
}

func test_result_err_variant() test -> Expected(string, "bad") {
    let r = Result.Err("bad")
    var msg: string = ""
    switch r {
    case .Ok(v):
        msg = ""
    case .Err(e):
        msg = e
    }
    return msg
}