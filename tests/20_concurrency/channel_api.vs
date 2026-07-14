package concurrency_test
build test

func test_send_receive_roundtrip() test -> Expected(int32, "5") {
    let ch = chan[int32](1)
    ch.send(5)
    return ch.receive()
}

func test_trysend_succeeds_when_room() test -> Expected(bool, "1") {
    let ch = chan[int32](1)
    let ok = ch.trySend(1)
    return ok
}

func test_trysend_fails_when_full() test -> Expected(bool, "0") {
    let ch = chan[int32](1)
    ch.trySend(1)
    let ok = ch.trySend(2)
    return ok
}

func test_tryreceive_returns_value_when_available() test -> Expected(int32, "7") {
    let ch = chan[int32](1)
    ch.send(7)
    let val, err = ch.tryReceive()
    return val
}

func test_tryreceive_empty_error_string_on_success() test -> Expected(bool, "1") {
    let ch = chan[int32](1)
    ch.send(7)
    let val, err = ch.tryReceive()
    return err == ""
}

func test_tryreceive_nonempty_error_when_nothing_available() test -> Expected(bool, "1") {
    let ch = chan[int32](1)
    let val, err = ch.tryReceive()
    return err != ""
}

func test_tryreceive_zero_value_when_nothing_available() test -> Expected(int32, "0") {
    let ch = chan[int32](1)
    let val, err = ch.tryReceive()
    return val
}

func test_close_then_drained_tryreceive_errors() test -> Expected(bool, "1") {
    let ch = chan[int32](1)
    ch.send(1)
    ch.close()
    let v1, e1 = ch.tryReceive()   // drains the sent value
    let v2, e2 = ch.tryReceive()   // closed and drained
    return e2 != ""
}