package first_class_functions_test
build test

func apply(x: int32, f: func(int32) -> int32) -> int32 {
    return f(x)
}

func makeAdder(n: int32) -> func(int32) -> int32 {
    return func(x: int32) -> int32 {
        return x + n    // n captured by value
    }
}

func test_fn_type_stored_and_called() test -> Expected("10") {
    let double: func(int32) -> int32 = func(n: int32) -> int32 {
        return n * 2
    }
    return apply(x: 5, f: double)
}

func test_fn_returned_from_function() test -> Expected("15") {
    let add10 = makeAdder(n: 10)
    return add10(5)
}

func test_fn_inline_passed() test -> Expected("25") {
    return apply(x: 5, f: func(n: int32) -> int32 {
        return n * n
    })
}

func test_fn_void_return_no_crash() test {
    let log: func(int32) = func(n: int32) { }
    log(42)
}