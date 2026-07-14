package anonymous_functions_test
build test

func test_mutating_capture_compile_error() test -> Expected(error) {
    var count: int32 = 0
    let increment = func() {
        count += 1
    }
}

func illegal_setFilter(filter: func(int32) -> int32) {
}

func test_capturing_closure_cannot_cross_boundary() test -> Expected(error) {
    var count: int32 = 0
    illegal_setFilter(func(code: int32) -> int32 {
        count += 1
        return 0
    })
}

func test_function_type_arity_mismatch() test -> Expected(error) {
    let f: func(int32) -> int32 = func(a: int32, b: int32) -> int32 {
        return a + b
    }
}

func test_function_return_type_mismatch() test -> Expected(error) {
    let f: func(int32) -> int32 = func(n: int32) -> string {
        return "wrong"
    }
}