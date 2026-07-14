package anonymous_functions_test
build test

func makeAdder(n: int32) -> func(int32) -> int32 {
    return func(x: int32) -> int32 {
        return x + n
    }
}

func test_returned_closure_captures_param() test -> Expected(int32, "15") {
    let add10 = makeAdder(10)
    return add10(5)
}

func test_two_returned_closures_independent() test -> Expected(int32, "3") {
    let add1 = makeAdder(1)
    let add2 = makeAdder(2)
    return add1(1) + add2(0)
}