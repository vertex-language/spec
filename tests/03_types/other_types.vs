package types_test
build test

func test_bool_true() test -> Expected("1") {
    let x: bool = true
    return x
}

func test_bool_false() test -> Expected("0") {
    let x: bool = false
    return x
}

func test_char_val() test -> Expected("A") {
    let x: char = "A"
    return x
}

func test_string_val() test -> Expected("vertex") {
    let x: string = "vertex"
    return x
}