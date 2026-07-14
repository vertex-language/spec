package tuples_test
build test

func connect(host: string) -> ((), string) {
    if host == "" {
        return (), "empty host"
    }
    return (), ""
}

func test_unit_return_success_no_error() test -> Expected(bool, "1") {
    let unit, err = connect("localhost")
    return err == ""
}

func test_unit_return_failure_has_error() test -> Expected(bool, "1") {
    let unit, err = connect("")
    return err != ""
}