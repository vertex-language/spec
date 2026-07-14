package concurrency_test
build test

func conc_fetch(id: int32) -> int32 {
    return id * 2
}

func conc_heavy_compute(data: int32) -> int32 {
    return data + 100
}

func test_async_sigil_call() test -> Expected(int32, "10") {
    let a = async conc_fetch(5)
    return a.receive()
}

func test_thread_sigil_call() test -> Expected(int32, "105") {
    let b = thread conc_heavy_compute(5)
    return b.receive()
}

func test_same_function_called_synchronously_with_no_sigil() test -> Expected(int32, "10") {
    return conc_fetch(5)
}

func test_same_function_called_with_thread_sigil() test -> Expected(int32, "10") {
    let w = thread conc_fetch(5)
    return w.receive()
}