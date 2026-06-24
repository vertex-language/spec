package main
build test

func test_bool_true() test -> Expected(bool, "1") {
    var b: bool = true
    return b
}

func test_bool_false() test -> Expected(bool, "0") {
    var b: bool = false
    return b
}