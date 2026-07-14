package arrays_test
build test

func test_slice_head_length() test -> Expected(int32, "4") {
    var buf: []int32 = [10, 20, 30, 40, 50, 60]
    let head = buf[0..4]
    return head.length
}

func test_slice_head_first_element() test -> Expected(int32, "10") {
    var buf: []int32 = [10, 20, 30, 40, 50, 60]
    let head = buf[0..4]
    return head[0]
}

func test_slice_tail_length() test -> Expected(int32, "3") {
    var items: []int32 = [1, 2, 3, 4, 5]
    let tail = items[2..items.length]
    return tail.length
}

func test_slice_tail_first_element() test -> Expected(int32, "3") {
    var items: []int32 = [1, 2, 3, 4, 5]
    let tail = items[2..items.length]
    return tail[0]
}

func test_slice_middle_range() test -> Expected(int32, "2") {
    var items: []int32 = [1, 2, 3, 4, 5]
    let middle = items[1..3]
    return middle.length
}

func test_slice_view_is_two_words_no_owning() test -> Expected(int32, "20") {
    var buf: []int32 = [10, 20, 30]
    let view = buf[1..2]
    return view[0]
}