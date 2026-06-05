package literals_test
build test

func test_bool_true() test -> Expected("1") {
    var b: bool = true
    return b
}

func test_bool_false() test -> Expected("0") {
    var b: bool = false
    return b
}