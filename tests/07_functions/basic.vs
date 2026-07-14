package functions_test
build test

func add(a: int32, b: int32) -> int32 {
    return a + b
}

func test_basic_call() test -> Expected(int32, "3") {
    return add(1, 2)
}

func test_return_value_used_in_binding() test -> Expected(int32, "10") {
    let sum = add(4, 6)
    return sum
}

func noReturn() {
}

func test_void_function_call() test -> Expected(bool, "1") {
    noReturn()
    return true
}

func square(n: int32) -> int32 {
    return n * n
}

func test_nested_call() test -> Expected(int32, "25") {
    return square(add(2, 3))
}