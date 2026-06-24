package defer_test
build test

// Helper: runs deferred cleanup through a pointer so the effect is observable
func withDefer(out: *int32) {
    defer func() { out = 99 }()
    // out is still 0 here; defer fires on exit
}

func test_defer_anon_form_runs_on_exit() test -> Expected(int32, "99") {
    var x: int32 = 0
    withDefer(out: &x)
    return x
}

// LIFO ordering — second defer declared runs first
func lifoHelper(a: *int32, b: *int32) {
    defer func() { a = 1 }()    // declared first — runs second
    defer func() { b = 2 }()    // declared second — runs first
}

func test_defer_lifo_second_declared_runs_first() test -> Expected(int32, "2") {
    var a: int32 = 0
    var b: int32 = 0
    lifoHelper(a: &a, b: &b)
    // b was set by the second-declared defer (which ran first)
    return b
}

func test_defer_lifo_first_declared_runs_second() test -> Expected(int32, "1") {
    var a: int32 = 0
    var b: int32 = 0
    lifoHelper(a: &a, b: &b)
    return a
}

// defer does not affect the return value — value is captured before defers run
func returnThenDefer() -> int32 {
    var x: int32 = 5
    defer func() { x = 99 }()
    return x    // returns 5; defer fires after but cannot change the returned value
}

func test_defer_does_not_affect_return_value() test -> Expected(int32, "5") {
    return returnThenDefer()
}