package anon_functions_test
build test

func apply(x: int32, f: func(int32) -> int32) -> int32 {
    return f(x)
}

func applyTwice(x: int32, f: func(int32) -> int32) -> int32 {
    return f(f(x))
}

func makeAdder(n: int32) -> func(int32) -> int32 {
    return func(x: int32) -> int32 { return x + n }
}

func test_higher_order_square() test -> Expected(int32, "25") {
    return apply(5, func(n: int32) -> int32 { return n * n })
}

func test_higher_order_double() test -> Expected(int32, "14") {
    return apply(7, func(n: int32) -> int32 { return n * 2 })
}

func test_apply_twice() test -> Expected(int32, "20") {
    return applyTwice(5, func(n: int32) -> int32 { return n * 2 })
}

func test_returned_function() test -> Expected(int32, "13") {
    let add10 = makeAdder(10)
    return add10(3)
}

func test_function_as_variable_reassigned() test -> Expected(int32, "8") {
    var f: func(int32) -> int32 = func(n: int32) -> int32 { return n + 1 }
    f = func(n: int32) -> int32 { return n * 2 }
    return f(4)
}