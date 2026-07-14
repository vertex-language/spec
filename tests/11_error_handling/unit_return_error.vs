package error_handling_test
build test

func connect(host: string, port: uint16) -> ((), string) {
    if host == "" {
        return (), "empty host"
    }
    return (), ""
}

func test_unit_return_success() test -> Expected(bool, "1") {
    let unit, err = connect(host: "localhost", port: 8080)
    return err == ""
}

func test_unit_return_failure() test -> Expected(bool, "1") {
    let unit, err = connect(host: "", port: 8080)
    return err != ""
}