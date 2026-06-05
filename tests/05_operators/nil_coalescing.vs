package operators_test
build test

func test_nil_coalescing_nil_gives_default() test -> Expected("42") {
    var x: int32? = nil
    return x ?? 42
}

func test_nil_coalescing_value_passes_through() test -> Expected("10") {
    var x: int32? = 10
    return x ?? 42
}

func test_nil_coalescing_string_nil() test -> Expected("default") {
    var s: string? = nil
    return s ?? "default"
}

func test_nil_coalescing_string_value() test -> Expected("hello") {
    var s: string? = "hello"
    return s ?? "default"
}

func test_nil_coalescing_chained() test -> Expected("99") {
    var a: int32? = nil
    var b: int32? = nil
    var c: int32? = 99
    return a ?? b ?? c ?? 0
}