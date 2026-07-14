package functions_test
build test

func double(n: int32) -> int32 {
    return n * 2
}

func test_function_value_call() test -> Expected(int32, "8") {
    let d: func(int32) -> int32 = double
    return d(4)
}

func apply(values: []int32, f: func(int32) -> int32) -> []int32 {
    var result: []int32 = []
    for v in values {
        result.push(f(v))
    }
    return result
}

func test_apply_higher_order() test -> Expected(int32, "4") {
    let nums = [1, 2, 3]
    let doubled = apply(nums, double)
    return doubled[1]
}

func makeAdder(n: int32) -> func(int32) -> int32 {
    return func(x: int32) -> int32 {
        return x + n
    }
}

func test_returned_closure() test -> Expected(int32, "15") {
    let add10 = makeAdder(10)
    return add10(5)
}

func test_void_function_type() test -> Expected(bool, "1") {
    var fired = false
    let onFire: func(int32) = func(n: int32) {
        fired = true
    }
    onFire(1)
    return fired
}