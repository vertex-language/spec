package functions_test
build test

func addInts(a: int32, b: int32) -> int32 {
    return a + b
}

func test_call_with_wrong_type() test -> Expected(error) {
    return addInts(1, "two")
}

func incr(n: mut int32) {
    n += 1
}

func test_let_cannot_be_mut_arg() test -> Expected(error) {
    let x: int32 = 5
    incr(x)
}

func test_too_few_args() test -> Expected(error) {
    return addInts(1)
}

func test_too_many_args() test -> Expected(error) {
    return addInts(1, 2, 3)
}