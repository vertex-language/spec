package error_handling_test
build test

func parseInt(s: string) -> (int32, string) {
    if s == "" { return 0, "empty string" }
    return 42, ""
}

func test_check_then_use() test -> Expected(int32, "42") {
    let n, err = parseInt(s: "42")
    if err != "" {
        return -1
    }
    return n
}

func test_check_then_handle_failure() test -> Expected(int32, "-1") {
    let n, err = parseInt(s: "")
    if err != "" {
        return -1
    }
    return n
}