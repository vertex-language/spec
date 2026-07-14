package functions_test
build test

func increment(n: mut int32) {
    n += 1
}

func test_mut_param_mutates_caller() test -> Expected(int32, "1") {
    var count: int32 = 0
    increment(count)
    return count
}

func test_mut_param_multiple_calls() test -> Expected(int32, "3") {
    var count: int32 = 0
    increment(count)
    increment(count)
    increment(count)
    return count
}

func swap(a: mut int32, b: mut int32) {
    let tmp = a
    a = b
    b = tmp
}

func test_mut_params_swap() test -> Expected(int32, "2") {
    var x: int32 = 1
    var y: int32 = 2
    swap(x, y)
    return x
}

func test_mut_params_swap_second() test -> Expected(int32, "1") {
    var x: int32 = 1
    var y: int32 = 2
    swap(x, y)
    return y
}