package concurrency_test
build test

func crunch_numbers(seed: int32) -> float32 {
    return float32(seed) * 2.0
}

func test_thread_returns_channel_of_t() test -> Expected(float32, "210.000000") {
    let worker = thread func(seed: int32) -> float32 {
        return crunch_numbers(seed)
    }(105)

    let final_data = worker.receive()
    return final_data
}

func test_async_single_return_receive() test -> Expected(int32, "42") {
    let worker = async func() -> int32 {
        return 42
    }()
    return worker.receive()
}