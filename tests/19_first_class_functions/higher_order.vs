package first_class_functions_test
build test

func applyTwice(x: int32, f: func(int32) -> int32) -> int32 {
    return f(f(x))
}

func compose(x: int32, f: func(int32) -> int32, g: func(int32) -> int32) -> int32 {
    return g(f(x))
}

func reduce(items: [int32], init: int32, f: func(int32, int32) -> int32) -> int32 {
    var acc: int32 = init
    for v in items {
        acc = f(acc, v)
    }
    return acc
}

func test_apply_twice_double() test -> Expected("20") {
    let double = func(n: int32) -> int32 { return n * 2 }
    return applyTwice(x: 5, f: double)    // 5 → 10 → 20
}

func test_compose_double_then_add() test -> Expected("11") {
    let double = func(n: int32) -> int32 { return n * 2 }
    let addOne = func(n: int32) -> int32 { return n + 1 }
    return compose(x: 5, f: double, g: addOne)    // 5 → 10 → 11
}

func test_reduce_sum() test -> Expected("15") {
    let nums = [1, 2, 3, 4, 5]
    return reduce(items: nums, init: 0, f: func(acc: int32, x: int32) -> int32 {
        return acc + x
    })
}

func test_reduce_product() test -> Expected("24") {
    let nums = [1, 2, 3, 4]
    return reduce(items: nums, init: 1, f: func(acc: int32, x: int32) -> int32 {
        return acc * x
    })
}

func test_reduce_max() test -> Expected("9") {
    let nums = [3, 9, 1, 7, 2]
    return reduce(items: nums, init: nums[0], f: func(acc: int32, x: int32) -> int32 {
        return acc > x ? acc : x
    })
}