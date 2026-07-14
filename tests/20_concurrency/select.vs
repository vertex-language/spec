package concurrency_test
build test

func test_select_receives_available_case() test -> Expected(int32, "1") {
    let ch = chan[int32](1)
    ch.send(9)

    var result: int32 = 0
    select {
    case a = ch.receive():
        result = 1
    default:
        result = 2
    }
    return result
}

func test_select_falls_to_default_when_nothing_ready() test -> Expected(int32, "2") {
    let ch = chan[int32](1)

    var result: int32 = 0
    select {
    case a = ch.receive():
        result = 1
    default:
        result = 2
    }
    return result
}

func test_select_between_two_channels() test -> Expected(int32, "1") {
    let ch1 = chan[int32](1)
    let ch2 = chan[int32](1)
    ch1.send(5)

    var result: int32 = 0
    select {
    case a = ch1.receive():
        result = 1
    case b = ch2.receive():
        result = 2
    default:
        result = 3
    }
    return result
}

func test_select_captures_received_value() test -> Expected(int32, "42") {
    let ch = chan[int32](1)
    ch.send(42)

    var result: int32 = 0
    select {
    case a = ch.receive():
        result = a
    default:
        result = -1
    }
    return result
}