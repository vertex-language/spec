package optionals_test
build test

func test_optional_nil_coalesces() test -> Expected(int32, "-1") {
    var x: int32? = nil
    return x ?? -1
}

func test_optional_value_passes_through() test -> Expected(int32, "5") {
    var x: int32? = 5
    return x ?? -1
}

func test_optional_reassign_nil_to_value() test -> Expected(int32, "10") {
    var x: int32? = nil
    x = 10
    return x ?? -1
}

func test_optional_reassign_value_to_nil() test -> Expected(int32, "-1") {
    var x: int32? = 5
    x = nil
    return x ?? -1
}

func test_optional_bool() test -> Expected(bool, "1") {
    var b: bool? = true
    return b ?? false
}

func test_optional_string_nil() test -> Expected(string, "none") {
    var s: string? = nil
    return s ?? "none"
}