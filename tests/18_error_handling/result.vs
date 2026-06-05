package error_handling_test
build test

func parseInt(s: string) -> Result(int32, string) {
    if s == ""    { return Result(Err, "empty") }
    if s == "42"  { return Result(Ok, 42) }
    if s == "0"   { return Result(Ok, 0) }
    if s == "100" { return Result(Ok, 100) }
    return Result(Err, "not a number")
}

func test_result_if_let_ok() test -> Expected("42") {
    if let value = parseInt(s: "42") {
        return value
    }
    return -1
}

func test_result_if_let_err_skips() test -> Expected("-1") {
    if let value = parseInt(s: "") {
        return value
    }
    return -1
}

func test_result_switch_ok_branch() test -> Expected("42") {
    switch parseInt(s: "42") {
    case Ok(let value):
        return value
    case Err(let err):
        return -1
    }
}

func test_result_switch_err_branch() test -> Expected("error") {
    switch parseInt(s: "") {
    case Ok(let value):
        return "ok"
    case Err(let err):
        return "error"
    }
}

func test_result_zero_ok() test -> Expected("0") {
    if let value = parseInt(s: "0") {
        return value
    }
    return -1
}