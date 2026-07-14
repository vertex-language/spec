package anonymous_functions_test
build test

func nc_double(n: int32) -> int32 {
    return n * 2
}

func test_non_capturing_bare_function_value() test -> Expected(int32, "8") {
    let d: func(int32) -> int32 = nc_double
    return d(4)
}

func test_non_capturing_anonymous_literal() test -> Expected(int32, "6") {
    let triple: func(int32) -> int32 = func(n: int32) -> int32 {
        return n * 3
    }
    return triple(2)
}

func test_capturing_closure_reads_outer_binding() test -> Expected(int32, "15") {
    let base: int32 = 10
    let addBase = func(n: int32) -> int32 {
        return n + base
    }
    return addBase(5)
}