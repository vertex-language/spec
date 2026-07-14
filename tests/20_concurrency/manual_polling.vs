package concurrency_test
build test

func poll_crunch_data() -> int32 {
    return 1
}

func poll_fetch_network() -> int32 {
    return 2
}

func test_manual_polling_detects_first_task() test -> Expected(int32, "1") {
    let task1 = thread poll_crunch_data()
    let task2 = thread poll_fetch_network()

    var result: int32 = 0
    var waiting = true
    while waiting {
        let a, err1 = task1.tryReceive()
        if err1 == "" {
            result = 1
            waiting = false
            continue
        }

        let b, err2 = task2.tryReceive()
        if err2 == "" {
            result = 2
            waiting = false
            continue
        }

        runtime.yield()
    }
    return result
}