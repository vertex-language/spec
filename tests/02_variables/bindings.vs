package variables_test
build test

func test_let_int() test -> Expected(int32, "10") {
    let x: int32 = 10
    return x
}

func test_var_int() test -> Expected(int32, "20") {
    var x: int32 = 20
    return x
}

func test_var_reassign() test -> Expected(int32, "99") {
    var x: int32 = 5
    x = 99
    return x
}

func test_let_inferred() test -> Expected(int32, "42") {
    let x = 42
    return x
}

func test_var_inferred() test -> Expected(int32, "7") {
    var x = 7
    return x
}

func test_var_compound_add() test -> Expected(int32, "6") {
    var x: int32 = 5
    x += 1
    return x
}

func test_var_compound_mul() test -> Expected(int32, "20") {
    var x: int32 = 4
    x *= 5
    return x
}