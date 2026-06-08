package error_handling_test
build test

func divide(a: int32, b: int32) -> (int32, string?) {
    if b == 0 { return (0, "division by zero") }
    return (a / b, nil)
}

func test_tuple_ok_result() test -> Expected("5") {
    let (result, err) = divide(a: 10, b: 2)
    if err != nil { return -1 }
    return result
}

func test_tuple_err_non_nil() test -> Expected("1") {
    let (result, err) = divide(a: 10, b: 0)
    return err != nil
}

func test_tuple_err_zero_result() test -> Expected("0") {
    let (result, err) = divide(a: 10, b: 0)
    return result
}

func test_tuple_ok_no_error() test -> Expected("0") {
    let (result, err) = divide(a: 6, b: 3)
    return err != nil    // no error
}