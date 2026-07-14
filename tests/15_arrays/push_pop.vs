package arrays_test
build test

func test_push_increases_length() test -> Expected(int32, "1") {
    var items: []int32 = []
    items.push(42)
    return items.length
}

func test_push_appends_at_end() test -> Expected(int32, "42") {
    var items: []int32 = []
    items.push(10)
    items.push(42)
    return items[1]
}

func test_multiple_pushes() test -> Expected(int32, "3") {
    var items: []int32 = []
    items.push(1)
    items.push(2)
    items.push(3)
    return items.length
}

func test_pop_returns_last_element() test -> Expected(int32, "3") {
    var items: []int32 = [1, 2, 3]
    let last = items.pop()
    return last
}

func test_pop_reduces_length() test -> Expected(int32, "2") {
    var items: []int32 = [1, 2, 3]
    let last = items.pop()
    return items.length
}

func test_push_after_pop() test -> Expected(int32, "9") {
    var items: []int32 = [1, 2, 3]
    let last = items.pop()
    items.push(9)
    return items[2]
}