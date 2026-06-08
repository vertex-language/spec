package optionals_test
build test

func test_if_let_unwraps_value() test -> Expected("42") {
    var x: int32? = 42
    if let val = x {
        return val
    }
    return -1
}

func test_if_let_nil_skips_body() test -> Expected("-1") {
    var x: int32? = nil
    if let val = x {
        return val
    }
    return -1
}

func test_if_let_string_value() test -> Expected("hello") {
    var s: string? = "hello"
    if let str = s {
        return str
    }
    return "none"
}

func test_if_let_string_nil() test -> Expected("none") {
    var s: string? = nil
    if let str = s {
        return str
    }
    return "none"
}

func test_if_let_bool_true() test -> Expected("1") {
    var b: bool? = true
    if let val = b {
        return val
    }
    return false
}