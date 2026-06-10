package arrays_test
build test

func test_fixed_literal_first() test -> Expected(int32, "1") {
    let arr = [1, 2, 3]
    return arr[0]
}

func test_fixed_literal_middle() test -> Expected(int32, "2") {
    let arr = [1, 2, 3]
    return arr[1]
}

func test_fixed_literal_last() test -> Expected(int32, "3") {
    let arr = [1, 2, 3]
    return arr[2]
}

func test_fixed_length() test -> Expected(int32, "3") {
    let arr = [1, 2, 3]
    return arr.length
}

func test_fixed_annotated() test -> Expected(int32, "10") {
    let arr: [int32; 3] = [10, 20, 30]
    return arr[0]
}

func test_fixed_var_write() test -> Expected(int32, "99") {
    var arr: [int32; 3] = [10, 20, 30]
    arr[0] = 99
    return arr[0]
}

func test_fixed_zero_fill() test -> Expected(int32, "0") {
    var buf: [int32; 4]
    return buf[0]
}

func test_fixed_fill() test -> Expected(int32, "7") {
    var arr: [int32; 3] = [1, 2, 3]
    arr.fill(7)
    return arr[0]
}

func test_fixed_for_in_sum() test -> Expected(int32, "6") {
    let arr = [1, 2, 3]
    var sum: int32 = 0
    for n in arr {
        sum += n
    }
    return sum
}