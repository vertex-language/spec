package arrays_test
build test

func test_in_place_sort_first() test -> Expected("1") {
    var items = [int32]()
    defer items.delete()
    items.push(30)
    items.push(10)
    items.push(20)
    items.sort(func(a: int32, b: int32) -> int32 {
        return a - b
    })
    return items[0]
}

func test_in_place_sort_last() test -> Expected("30") {
    var items = [int32]()
    defer items.delete()
    items.push(30)
    items.push(10)
    items.push(20)
    items.sort(func(a: int32, b: int32) -> int32 {
        return a - b
    })
    return items[2]
}

func test_in_place_reverse_first() test -> Expected("30") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    items.reverse()
    return items[0]
}

func test_in_place_reverse_last() test -> Expected("10") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    items.reverse()
    return items[2]
}

func test_in_place_fill_all() test -> Expected("0") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(10)
    items.fill(0)
    return items[0]
}

func test_in_place_fill_range_untouched() test -> Expected("5") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(10)
    items.push(15)
    items.fill(0, from: 1, to: 3)
    return items[0]    // index 0 is outside fill range, unchanged
}