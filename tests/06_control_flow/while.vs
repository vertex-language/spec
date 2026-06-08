package control_flow_test
build test

func test_while_counts_up() test -> Expected(int32, "5") {
    var i: int32 = 0
    while i < 5 {
        i += 1
    }
    return i
}

func test_while_skipped_when_false() test -> Expected(int32, "0") {
    var i: int32 = 0
    while i > 0 {
        i += 1
    }
    return i
}

func test_while_accumulates() test -> Expected(int32,"10") {
    var sum: int32 = 0
    var i: int32 = 1
    while i <= 4 {
        sum += i    // 1+2+3+4 = 10
        i += 1
    }
    return sum
}

func test_while_true_break() test -> Expected(int32, "5") {
    var n: int32 = 0
    while true {
        if n >= 5 { break }
        n += 1
    }
    return n
}