package control_flow_test
build test

func test_if_true_branch() test -> Expected(string, "positive") {
    let x: int32 = 5
    if x > 0 {
        return "positive"
    }
    return "other"
}

func test_if_false_skips_body() test -> Expected(string, "other") {
    let x: int32 = -5
    if x > 0 {
        return "positive"
    }
    return "other"
}

func test_if_else() test -> Expected(string, "negative") {
    let x: int32 = -5
    if x > 0 {
        return "positive"
    } else {
        return "negative"
    }
}

func test_else_if_first() test -> Expected(string, "positive") {
    let x: int32 = 5
    if x > 0 {
        return "positive"
    } else if x < 0 {
        return "negative"
    } else {
        return "zero"
    }
}

func test_else_if_second() test -> Expected(string, "negative") {
    let x: int32 = -3
    if x > 0 {
        return "positive"
    } else if x < 0 {
        return "negative"
    } else {
        return "zero"
    }
}

func test_else_fallthrough_to_zero() test -> Expected(string, "zero") {
    let x: int32 = 0
    if x > 0 {
        return "positive"
    } else if x < 0 {
        return "negative"
    } else {
        return "zero"
    }
}

func test_if_compound_and() test -> Expected(bool, "1") {
    let a: int32 = 10
    let b: int32 = 20
    if a < b && b < 30 {
        return true
    }
    return false
}

func test_if_compound_or() test -> Expected(bool, "1") {
    let a: int32 = 50
    let b: int32 = 5
    if a < 10 || b < 10 {
        return true
    }
    return false
}