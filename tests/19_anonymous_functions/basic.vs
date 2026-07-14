package anonymous_functions_test
build test

func test_stored_in_variable() test -> Expected(int32, "8") {
    let double = func(n: int32) -> int32 { return n * 2 }
    return double(4)
}

func test_void_return_arrow_omitted() test -> Expected(int32, "5") {
    var captured: int32 = 0
    let log = func(n: int32) { captured = n }
    log(5)
    return captured
}

func test_anonymous_function_no_args() test -> Expected(int32, "7") {
    let makeSeven = func() -> int32 { return 7 }
    return makeSeven()
}

func test_anonymous_function_multiple_args() test -> Expected(int32, "12") {
    let mul = func(a: int32, b: int32) -> int32 { return a * b }
    return mul(3, 4)
}