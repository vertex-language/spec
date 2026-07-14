package functions_test
build test

func sumAll(nums: ...int32) -> int32 {
    var total: int32 = 0
    for n in nums {
        total += n
    }
    return total
}

func test_variadic_multiple_args() test -> Expected(int32, "6") {
    return sumAll(1, 2, 3)
}

func test_variadic_zero_args() test -> Expected(int32, "0") {
    return sumAll()
}

func test_variadic_single_arg() test -> Expected(int32, "5") {
    return sumAll(5)
}

func log(prefix: string, msg: ...string) -> int32 {
    var count: int32 = 0
    for m in msg {
        count += 1
    }
    return count
}

func test_variadic_with_leading_param() test -> Expected(int32, "2") {
    return log("info", "starting", "ready")
}