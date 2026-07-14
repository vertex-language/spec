package functions_test
build test

func subtract(a: int32, b: int32) -> int32 {
    return a - b
}

func test_positional_args() test -> Expected(int32, "2") {
    return subtract(5, 3)
}

func test_named_args() test -> Expected(int32, "2") {
    return subtract(a: 5, b: 3)
}

func test_named_args_reordered() test -> Expected(int32, "2") {
    // named arguments resolve to positional order at compile time
    // (foundation_spec.md §9), so order at the call site doesn't matter
    return subtract(b: 3, a: 5)
}