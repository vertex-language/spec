package arrays_test
build test

func test_dynamic_literal_element() test -> Expected(int32, "20") {
    var arr = [10, 20, 30]
    defer arr.delete()
    return arr[1]
}

func test_dynamic_literal_length() test -> Expected(int32, "3") {
    var arr = [10, 20, 30]
    defer arr.delete()
    return arr.length
}

func test_dynamic_empty_length() test -> Expected(int32, "0") {
    var arr: [int32] = []
    defer arr.delete()
    return arr.length
}

func test_dynamic_push_value() test -> Expected(int32, "42") {
    var arr: [int32] = []
    defer arr.delete()
    arr.push(42)
    return arr[0]
}

func test_dynamic_push_length() test -> Expected(int32, "4") {
    var arr = [10, 20, 30]
    defer arr.delete()
    arr.push(40)
    return arr.length
}

func test_dynamic_pop_value() test -> Expected(int32, "30") {
    var arr = [10, 20, 30]
    defer arr.delete()
    let val = arr.pop()
    return val ?? -1
}

func test_dynamic_pop_length() test -> Expected(int32, "2") {
    var arr = [10, 20, 30]
    defer arr.delete()
    arr.pop()
    return arr.length
}

func test_dynamic_unshift_first() test -> Expected(int32, "0") {
    var arr = [10, 20, 30]
    defer arr.delete()
    arr.unshift(0)
    return arr[0]
}

func test_dynamic_shift_value() test -> Expected(int32, "10") {
    var arr = [10, 20, 30]
    defer arr.delete()
    let val = arr.shift()
    return val ?? -1
}

func test_dynamic_write() test -> Expected(int32, "99") {
    var arr = [10, 20, 30]
    defer arr.delete()
    arr[1] = 99
    return arr[1]
}