package first_class_functions_test
build test

func test_anon_stored_and_called() test -> Expected("10") {
    let double = func(n: int32) -> int32 { return n * 2 }
    return double(5)
}

func test_anon_captures_value() test -> Expected("15") {
    let factor = 3
    let multiply = func(n: int32) -> int32 {
        return n * factor    // factor captured by value at creation
    }
    return multiply(5)
}

func test_anon_in_map() test -> Expected("100") {
    var items = [int32]()
    defer items.delete()
    items.push(10)
    var result = items.map(func(x: int32) -> int32 {
        return x * 10
    })
    defer result.delete()
    return result[0]
}

func test_anon_in_filter() test -> Expected("1") {
    var items = [int32]()
    defer items.delete()
    items.push(1)
    items.push(2)
    items.push(3)
    var big = items.filter(func(x: int32) -> bool {
        return x > 2
    })
    defer big.delete()
    return big.length    // only 3 passes
}

func test_anon_return_exits_anon_only() test -> Expected("5") {
    let clamp = func(n: int32) -> int32 {
        if n < 0 { return 0 }
        if n > 5 { return 5 }
        return n              // return exits anonymous function
    }
    return clamp(10)    // clamped to 5
}