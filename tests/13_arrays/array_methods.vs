package arrays_test
build test

// ── search ────────────────────────────────────────────────────────────────────

func test_index_of_found() test -> Expected(int32, "1") {
    var arr = [10, 20, 30]
    defer arr.delete()
    return arr.indexOf(20)
}

func test_index_of_not_found() test -> Expected(int32, "-1") {
    var arr = [10, 20, 30]
    defer arr.delete()
    return arr.indexOf(99)
}

func test_includes_true() test -> Expected(bool, "1") {
    var arr = [1, 2, 3]
    defer arr.delete()
    return arr.includes(2)
}

func test_includes_false() test -> Expected(bool, "0") {
    var arr = [1, 2, 3]
    defer arr.delete()
    return arr.includes(99)
}

func test_find_returns_first_match() test -> Expected(int32, "3") {
    var arr = [1, 2, 3, 4, 5]
    defer arr.delete()
    let val = arr.find(func(x: int32) -> bool { return x > 2 })
    return val ?? -1
}

func test_find_no_match_returns_nil() test -> Expected(int32, "-1") {
    var arr = [1, 2, 3]
    defer arr.delete()
    let val = arr.find(func(x: int32) -> bool { return x > 99 })
    return val ?? -1
}

func test_find_index_found() test -> Expected(int32, "2") {
    var arr = [1, 2, 3, 4]
    defer arr.delete()
    return arr.findIndex(func(x: int32) -> bool { return x > 2 })
}

func test_find_index_not_found() test -> Expected(int32, "-1") {
    var arr = [1, 2, 3]
    defer arr.delete()
    return arr.findIndex(func(x: int32) -> bool { return x > 99 })
}

// ── in-place mutation ─────────────────────────────────────────────────────────

func test_sort_ascending_first() test -> Expected(int32, "1") {
    var arr = [3, 1, 2]
    defer arr.delete()
    arr.sort(func(a: int32, b: int32) -> int32 { return a - b })
    return arr[0]
}

func test_sort_ascending_last() test -> Expected(int32, "3") {
    var arr = [3, 1, 2]
    defer arr.delete()
    arr.sort(func(a: int32, b: int32) -> int32 { return a - b })
    return arr[2]
}

func test_sort_descending_first() test -> Expected(int32, "3") {
    var arr = [1, 3, 2]
    defer arr.delete()
    arr.sort(func(a: int32, b: int32) -> int32 { return b - a })
    return arr[0]
}

func test_reverse_first_becomes_last() test -> Expected(int32, "1") {
    var arr = [1, 2, 3]
    defer arr.delete()
    arr.reverse()
    return arr[2]
}

func test_reverse_last_becomes_first() test -> Expected(int32, "3") {
    var arr = [1, 2, 3]
    defer arr.delete()
    arr.reverse()
    return arr[0]
}

// ── allocating methods ────────────────────────────────────────────────────────

func test_filter_length() test -> Expected(int32, "2") {
    var arr = [1, 2, 3, 4, 5]
    defer arr.delete()
    var evens = arr.filter(func(x: int32) -> bool { return x % 2 == 0 })
    defer evens.delete()
    return evens.length
}

func test_filter_values() test -> Expected(int32, "4") {
    var arr = [1, 2, 3, 4, 5]
    defer arr.delete()
    var evens = arr.filter(func(x: int32) -> bool { return x % 2 == 0 })
    defer evens.delete()
    return evens[1]
}

func test_slice_length() test -> Expected(int32, "2") {
    var arr = [10, 20, 30, 40]
    defer arr.delete()
    var sub = arr.slice(1, 3)
    defer sub.delete()
    return sub.length
}

func test_slice_values() test -> Expected(int32, "20") {
    var arr = [10, 20, 30, 40]
    defer arr.delete()
    var sub = arr.slice(1, 3)
    defer sub.delete()
    return sub[0]
}

func test_concat_length() test -> Expected(int32, "5") {
    var a = [1, 2]
    defer a.delete()
    var b = [3, 4, 5]
    defer b.delete()
    var all = a.concat(b)
    defer all.delete()
    return all.length
}

func test_concat_values() test -> Expected(int32, "3") {
    var a = [1, 2]
    defer a.delete()
    var b = [3, 4, 5]
    defer b.delete()
    var all = a.concat(b)
    defer all.delete()
    return all[2]
}