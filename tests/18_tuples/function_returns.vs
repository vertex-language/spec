package tuples_test
build test

func minMax(nums: []int32) -> (int32, int32) {
    return nums[0], nums[0]
}

func test_bare_return_multiple_values() test -> Expected(int32, "1") {
    let nums = [1, 2, 3]
    let lo, hi = minMax(nums)
    return lo
}

func swapPair(a: int32, b: int32) -> (int32, int32) {
    return b, a
}

func test_function_return_swapped_first() test -> Expected(int32, "2") {
    let a, b = swapPair(1, 2)
    return a
}

func test_function_return_swapped_second() test -> Expected(int32, "1") {
    let a, b = swapPair(1, 2)
    return b
}