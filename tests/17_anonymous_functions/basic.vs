package anon_functions_test
build test

func test_anon_immediate_call() test -> Expected(int32, "10") {
    let result = func(n: int32) -> int32 { return n * 2 }(5)
    return result
}

func test_anon_stored_and_called() test -> Expected(int32, "9") {
    let square = func(n: int32) -> int32 { return n * n }
    return square(3)
}

func test_anon_capture_by_value() test -> Expected(int32, "15") {
    let factor: int32 = 3
    let multiply = func(n: int32) -> int32 { return n * factor }
    return multiply(5)
}

func test_anon_void_return() test -> Expected(int32, "42") {
    // void anon just runs — test that surrounding logic is unaffected
    let noop = func(n: int32) { }
    noop(0)
    return 42
}