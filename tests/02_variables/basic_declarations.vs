package variables_test
build test

func test_let_binding() test -> Expected(int32, "10") {
    let x = 10
    return x
}

func test_var_binding() test -> Expected(int32, "20") {
    var y = 20
    return y
}

func test_var_reassign() test -> Expected(int32, "5") {
    var y = 20
    y = 5
    return y
}

func test_var_compound_assign() test -> Expected(int32, "25") {
    var y = 20
    y += 5
    return y
}