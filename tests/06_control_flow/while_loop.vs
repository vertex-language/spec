package control_flow_test
build test

func test_while_basic() test -> Expected(int32, "5") {
    var i: int32 = 0
    while i < 5 {
        i += 1
    }
    return i
}

func test_while_reverse_step() test -> Expected(int32, "0") {
    var j: int32 = 100
    while j > 0 {
        j -= 10
    }
    return j
}

func test_while_true_with_break() test -> Expected(int32, "3") {
    var count: int32 = 0
    while true {
        count += 1
        if count == 3 { break }
    }
    return count
}

func test_while_never_runs() test -> Expected(int32, "0") {
    var count: int32 = 0
    while false {
        count += 1
    }
    return count
}