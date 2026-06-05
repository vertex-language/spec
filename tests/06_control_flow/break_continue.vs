package control_flow_test
build test

func test_break_stops_for_loop() test -> Expected("4") {
    var last: int32 = 0
    for n in 0..<10 {
        if n == 5 { break }
        last = n    // last valid assignment: n = 4
    }
    return last
}

func test_continue_skips_even() test -> Expected("25") {
    var sum: int32 = 0
    for i in 0..<10 {
        if i % 2 == 0 { continue }
        sum += i    // 1+3+5+7+9 = 25
    }
    return sum
}

func test_break_stops_while() test -> Expected("3") {
    var n: int32 = 0
    while true {
        n += 1
        if n == 3 { break }
    }
    return n
}

func test_continue_only_odd_count() test -> Expected("5") {
    var count: int32 = 0
    for i in 0..<10 {
        if i % 2 == 0 { continue }
        count += 1    // counts 1,3,5,7,9 → 5 times
    }
    return count
}