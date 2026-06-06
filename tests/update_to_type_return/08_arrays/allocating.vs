package arrays_test
build test

func test_alloc_map_doubles() test -> Expected("20") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(10)
    var doubled = items.map(func(x: int32) -> int32 {
        return x * 2
    })
    defer doubled.delete()
    return doubled[1]    // 10 * 2 = 20
}

func test_alloc_map_length() test -> Expected("2") {
    var items = [int32]()
    defer items.delete()
    items.push(1)
    items.push(2)
    var mapped = items.map(func(x: int32) -> int32 {
        return x + 1
    })
    defer mapped.delete()
    return mapped.length
}

func test_alloc_filter_evens_length() test -> Expected("2") {
    var items = [int32]()
    defer items.delete()
    for i in 1...5 {
        items.push(i)
    }
    var evens = items.filter(func(x: int32) -> bool {
        return x % 2 == 0
    })
    defer evens.delete()
    return evens.length    // 2 and 4
}

func test_alloc_filter_first_even() test -> Expected("2") {
    var items = [int32]()
    defer items.delete()
    for i in 1...5 {
        items.push(i)
    }
    var evens = items.filter(func(x: int32) -> bool {
        return x % 2 == 0
    })
    defer evens.delete()
    return evens[0]
}

func test_alloc_slice_value() test -> Expected("20") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    var sub = items.slice(1, 3)
    defer sub.delete()
    return sub[0]
}

func test_alloc_concat_length() test -> Expected("4") {
    var a = [int32]()
    defer a.delete()
    var b = [int32]()
    defer b.delete()
    a.push(1)
    a.push(2)
    b.push(3)
    b.push(4)
    var all = a.concat(b)
    defer all.delete()
    return all.length
}

func test_alloc_concat_values() test -> Expected("3") {
    var a = [int32]()
    defer a.delete()
    var b = [int32]()
    defer b.delete()
    a.push(1)
    a.push(2)
    b.push(3)
    b.push(4)
    var all = a.concat(b)
    defer all.delete()
    return all[2]
}