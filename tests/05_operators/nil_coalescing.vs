package operators_test
build test

func test_nil_coalescing_nil_gives_default() test -> Expected(int32, "42") {
    var x: int32? = nil
    return x ?? 42
}

func test_nil_coalescing_value_passes_through() test -> Expected(int32, "10") {
    var x: int32? = 10
    return x ?? 42
}

func test_nil_coalescing_string_nil() test -> Expected(string, "default") {
    var s: string? = nil
    return s ?? "default"
}

func test_nil_coalescing_string_value() test -> Expected(string, "hello") {
    var s: string? = "hello"
    return s ?? "default"
}

func test_nil_coalescing_chained() test -> Expected(int32, "99") {
    var a: int32? = nil
    var b: int32? = nil
    var c: int32? = 99
    return a ?? b ?? c ?? 0
}