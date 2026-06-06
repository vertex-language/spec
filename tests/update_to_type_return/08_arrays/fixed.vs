package arrays_test
build test

func test_fixed_zero_fill_short() test -> Expected("0") {
    var buf = [int32](5)
    return buf[0]
}

func test_fixed_zero_fill_last() test -> Expected("0") {
    var buf = [int32](5)
    return buf[4]
}

func test_fixed_repeating_nonzero() test -> Expected("255") {
    var mask = [uint8](repeating: 0xFF, count: 4)
    return mask[0]
}

func test_fixed_repeating_val() test -> Expected("7") {
    var arr = [int32](repeating: 7, count: 3)
    return arr[2]
}

func test_fixed_literal_access() test -> Expected("2") {
    let flags = [1, 2, 3]
    return flags[1]
}

func test_fixed_typed_literal() test -> Expected("3") {
    let typed: [uint8] = [1, 2, 3]
    return typed[2]
}

func test_fixed_write_then_read() test -> Expected("99") {
    var nums = [int32](5)
    nums[0] = 99
    return nums[0]
}

func test_fixed_write_multiple() test -> Expected("42") {
    var nums = [int32](3)
    nums[0] = 10
    nums[1] = 42
    nums[2] = 100
    return nums[1]
}

func test_fixed_nested_literal() test -> Expected("3") {
    let matrix = [[1, 2], [3, 4]]
    return matrix[1][0]
}