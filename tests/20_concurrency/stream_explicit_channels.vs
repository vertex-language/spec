package concurrency_test
build test

func stream_process(chunk: float32) -> float32 {
    return chunk * 2.0
}

func test_stream_send_and_tryreceive() test -> Expected(float32, "20.000000") {
    let out_stream = chan[float32](64)

    thread func(data: []float32, ch: chan float32) {
        for chunk in data {
            ch.send(stream_process(chunk))
        }
        ch.close()
    }([10.0], out_stream)

    var result: float32 = 0.0
    while true {
        let chunk, err = out_stream.tryReceive()
        if err != "" {
            break
        }
        result = chunk
    }
    return result
}

func test_stream_multiple_values_summed() test -> Expected(float32, "12.000000") {
    let out_stream = chan[float32](64)

    thread func(data: []float32, ch: chan float32) {
        for chunk in data {
            ch.send(chunk)
        }
        ch.close()
    }([2.0, 4.0, 6.0], out_stream)

    var sum: float32 = 0.0
    while true {
        let chunk, err = out_stream.tryReceive()
        if err != "" {
            break
        }
        sum += chunk
    }
    return sum
}