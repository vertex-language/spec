package anonymous_functions_test
build test

func writeback_run(n: mut int32, f: func(mut int32)) {
    f(n)
}

func test_writeback_via_mut_parameter() test -> Expected(int32, "10") {
    var total: int32 = 0
    writeback_run(total, func(n: mut int32) {
        n += 10
    })
    return total
}

func test_writeback_multiple_calls() test -> Expected(int32, "20") {
    var total: int32 = 0
    writeback_run(total, func(n: mut int32) {
        n += 10
    })
    writeback_run(total, func(n: mut int32) {
        n += 10
    })
    return total
}