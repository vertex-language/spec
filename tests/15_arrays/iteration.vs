package arrays_test
build test

func test_shared_iteration_sum() test -> Expected(int32, "6") {
    let nums = [1, 2, 3]
    var sum: int32 = 0
    for n in nums {
        sum += n
    }
    return sum
}

func test_exclusive_iteration_mutates_in_place() test -> Expected(int32, "2") {
    var nums = [1, 2, 3]
    for n in nums {
        n *= 2
    }
    return nums[0]
}

func test_index_value_iteration() test -> Expected(int32, "1") {
    let nums = [10, 20, 30]
    var foundIndex: int32 = -1
    for i, n in nums {
        if n == 20 {
            foundIndex = i
        }
    }
    return foundIndex
}

func test_consuming_transfer_iteration_leaves_container_dead() test -> Expected(int32, "0") {
    struct Frame {
        id: int32
    }
    var frames: []Frame = []
    frames.push(Frame{id: 1})
    frames.push(Frame{id: 2})

    var total: int32 = 0
    for f in frames.transfer() {
        total += f.id
    }
    return total
}