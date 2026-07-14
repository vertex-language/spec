package control_flow_test
build test

func test_for_array_shared_sum() test -> Expected(int32, "6") {
    let nums = [1, 2, 3]
    var sum: int32 = 0
    for n in nums {
        sum += n
    }
    return sum
}

func test_for_array_index_value() test -> Expected(int32, "1") {
    let nums = [10, 20, 30]
    var result: int32 = -1
    for i, n in nums {
        if n == 20 {
            result = i
        }
    }
    return result
}

func test_for_array_mutate_in_place() test -> Expected(int32, "2") {
    var nums = [1, 2, 3]
    for n in nums {
        n *= 2
    }
    return nums[0]
}