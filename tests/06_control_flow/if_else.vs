package control_flow_test
build test

func test_if_true_branch() test -> Expected(int32, "1") {
    let x: int32 = 5
    var result: int32 = 0
    if x > 0 {
        result = 1
    } else if x < 0 {
        result = -1
    } else {
        result = 0
    }
    return result
}

func test_else_if_branch() test -> Expected(int32, "-1") {
    let x: int32 = -5
    var result: int32 = 0
    if x > 0 {
        result = 1
    } else if x < 0 {
        result = -1
    } else {
        result = 0
    }
    return result
}

func test_else_branch() test -> Expected(int32, "0") {
    let x: int32 = 0
    var result: int32 = 99
    if x > 0 {
        result = 1
    } else if x < 0 {
        result = -1
    } else {
        result = 0
    }
    return result
}

func test_if_no_else() test -> Expected(bool, "1") {
    let x: int32 = 5
    var entered = false
    if x > 0 {
        entered = true
    }
    return entered
}