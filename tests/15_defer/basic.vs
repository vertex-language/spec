package defer_test
build test

class Handle {
    open: bool
}

func (h: *Handle) init() {
    h.open = true
}

func (h: *Handle) deinit() {
    h.open = false
}

func test_defer_delete_no_crash() test {
    let h = Handle()
    defer h.delete()
}

func test_defer_does_not_block_return() test -> Expected("42") {
    let h = Handle()
    defer h.delete()
    return 42           // defer runs after this
}

func test_defer_with_early_return() test -> Expected("1") {
    let h = Handle()
    defer h.delete()
    if true {
        return 1        // defer still runs at scope exit
    }
    return 0
}

func test_defer_multiple_no_crash() test {
    var a = Handle()
    var b = Handle()
    var c = Handle()
    defer a.delete()    // runs third (LIFO)
    defer b.delete()    // runs second
    defer c.delete()    // runs first
}

func test_defer_anonymous_no_crash() test {
    var x: int32 = 0
    defer func() { x += 1 }()    // captures x by value, runs at exit
}