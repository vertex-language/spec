package control_flow_test
build test

func test_slice_view_length() test -> Expected(int32, "4") {
    var buf: []int32 = [10, 20, 30, 40, 50, 60]
    let head = buf[0..4]
    return int32(head.length)
}

func test_slice_view_tail() test -> Expected(int32, "3") {
    var items: []int32 = [1, 2, 3, 4, 5]
    let tail = items[2..items.length]
    return int32(tail.length)
}

func test_slice_first_element() test -> Expected(int32, "20") {
    var buf: []int32 = [10, 20, 30, 40]
    let head = buf[1..3]
    return head[0]
}