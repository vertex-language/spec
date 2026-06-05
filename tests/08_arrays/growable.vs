package arrays_test
build test

func test_growable_empty_length() test -> Expected("0") {
    var items = [int32]()
    defer items.delete()
    return items.length
}

func test_growable_push_length() test -> Expected("3") {
    var items = [int32]()
    defer items.delete()
    items.push(1)
    items.push(2)
    items.push(3)
    return items.length
}

func test_growable_push_read() test -> Expected("42") {
    var items = [int32]()
    defer items.delete()
    items.push(42)
    return items[0]
}

func test_growable_pop_returns_last() test -> Expected("30") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    let last = items.pop()
    return last ?? -1
}

func test_growable_pop_reduces_length() test -> Expected("2") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    items.pop()
    return items.length
}

func test_growable_unshift_prepends() test -> Expected("0") {
    var items = [int32]()
    defer items.delete()
    items.push(1)
    items.push(2)
    items.unshift(0)
    return items[0]
}

func test_growable_shift_returns_first() test -> Expected("10") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    let first = items.shift()
    return first ?? -1
}

func test_growable_pop_empty_nil() test -> Expected("-1") {
    var items = [int32]()
    defer items.delete()
    let val = items.pop()
    return val ?? -1
}

func test_growable_with_capacity() test -> Expected("0") {
    var items = [int32](capacity: 64)
    defer items.delete()
    return items.length
}