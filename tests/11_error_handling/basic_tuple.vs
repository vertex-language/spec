package error_handling_test
build test

func parseInt(s: string) -> (int32, string) {
    if s == "" { return 0, "empty string" }
    return 42, ""
}

func test_success_path_value() test -> Expected(int32, "42") {
    let n, err = parseInt(s: "42")
    if err != "" {
        return -1
    }
    return n
}

func test_success_path_empty_error_string() test -> Expected(bool, "1") {
    let n, err = parseInt(s: "42")
    return err == ""
}

func test_failure_path_nonempty_error_string() test -> Expected(bool, "1") {
    let n, err = parseInt(s: "")
    return err != ""
}

func test_failure_path_zero_value() test -> Expected(int32, "0") {
    let n, err = parseInt(s: "")
    return n
}