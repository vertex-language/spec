package concurrency_test
build test

func test_unbuffered_channel_construction() test -> Expected(bool, "1") {
    let ch1 = chan[float32]()
    return ch1 != nil
}

func test_buffered_channel_construction() test -> Expected(bool, "1") {
    let ch2 = chan[int32](64)
    return ch2 != nil
}

func test_explicit_type_annotation_channel() test -> Expected(bool, "1") {
    let ch3: chan float32 = chan[float32]()
    return ch3 != nil
}

func test_buffered_channel_send_and_receive() test -> Expected(int32, "9") {
    let ch = chan[int32](4)
    ch.send(9)
    return ch.receive()
}