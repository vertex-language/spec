package error_handling_test
build test

func parseNum(s: string) -> Result(int32, string) {
    if s == "10"  { return Result(Ok, 10) }
    if s == "20"  { return Result(Ok, 20) }
    return Result(Err, "parse error")
}

func halved(s: string) -> Result(int32, string) {
    let n = parseNum(s: s).try()    // propagates Err if present
    return Result(Ok, n / 2)
}

func sumParsed(a: string, b: string) -> Result(int32, string) {
    let x = parseNum(s: a).try()
    let y = parseNum(s: b).try()
    return Result(Ok, x + y)
}

func test_try_ok_propagates_value() test -> Expected("5") {
    if let val = halved(s: "10") {
        return val
    }
    return -1
}

func test_try_err_propagates() test -> Expected("-1") {
    if let val = halved(s: "bad") {
        return val
    }
    return -1
}

func test_try_sum_ok() test -> Expected("30") {
    if let val = sumParsed(a: "10", b: "20") {
        return val
    }
    return -1
}

func test_try_sum_first_err() test -> Expected("-1") {
    if let val = sumParsed(a: "bad", b: "10") {
        return val
    }
    return -1
}