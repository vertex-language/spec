package arrays_test
build test

func test_search_index_of_found() test -> Expected("2") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    items.push(30)
    return items.indexOf(30)
}

func test_search_index_of_first() test -> Expected("0") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    return items.indexOf(10)
}

func test_search_index_of_not_found() test -> Expected("-1") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    items.push(20)
    return items.indexOf(99)
}

func test_search_includes_true() test -> Expected("1") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(10)
    return items.includes(5)
}

func test_search_includes_false() test -> Expected("0") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(10)
    return items.includes(99)
}

func test_search_find_first_match() test -> Expected("15") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(15)
    items.push(25)
    let val = items.find(func(x: int32) -> bool {
        return x > 10
    })
    return val ?? -1
}

func test_search_find_no_match() test -> Expected("-1") {
    var items = [int32]()
    defer items.delete()
    items.push(1)
    items.push(2)
    let val = items.find(func(x: int32) -> bool {
        return x > 100
    })
    return val ?? -1
}

func test_search_find_index() test -> Expected("1") {
    var items = [int32]()
    defer items.delete()
    items.push(5)
    items.push(15)
    items.push(25)
    return items.findIndex(func(x: int32) -> bool {
        return x > 10
    })
}