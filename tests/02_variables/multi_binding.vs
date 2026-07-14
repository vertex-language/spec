package variables_test
build test

func test_multi_let_binding() test -> Expected(int32, "3") {
    let a, b = 1, 2
    return a + b
}

func test_multi_var_binding() test -> Expected(int32, "30") {
    var a, b = 10, 20
    return a + b
}

func test_multi_var_reassign() test -> Expected(int32, "0") {
    var a, b = 1, 2
    a = 0
    b = 0
    return a + b
}