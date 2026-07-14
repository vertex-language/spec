package control_flow_test
build test

func test_break_stops_loop() test -> Expected(int32, "6") {
    var last: int32 = -1
    for i in 0..10 {
        if i == 7 { break }
        last = i
    }
    return last
}

func test_continue_skips_even() test -> Expected(int32, "5") {
    var count: int32 = 0
    for i in 0..10 {
        if i % 2 == 0 { continue }
        count += 1
    }
    return count
}

func test_break_in_while() test -> Expected(int32, "3") {
    var i: int32 = 0
    while true {
        if i == 3 { break }
        i += 1
    }
    return i
}