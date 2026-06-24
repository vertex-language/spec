package literals_test
build test

func test_char_literal() test -> Expected(char, "A") {
    let c: char = 'A'
    return c
}

func test_char_lowercase() test -> Expected(char, "z") {
    let c: char = 'z'
    return c
}

func test_char_digit() test -> Expected(char, "0") {
    let c: char = '0'
    return c
}