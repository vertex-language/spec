package arrays_test
build test

func test_array_length() test -> Expected(int32, "3") {
    let items = [1, 2, 3]
    return items.length
}

func test_array_index_read() test -> Expected(int32, "1") {
    let items = [1, 2, 3]
    return items[0]
}

func test_array_index_write() test -> Expected(int32, "99") {
    var items = [1, 2, 3]
    items[0] = 99
    return items[0]
}

func test_array_index_last_element() test -> Expected(int32, "3") {
    let items = [1, 2, 3]
    return items[items.length - 1]
}