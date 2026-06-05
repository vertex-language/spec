package literals_test
build test

func test_string_let() test -> Expected("hello") {
    let s: string = "hello"
    return s
}

func test_string_var() test -> Expected("world") {
    var s: string = "world"
    return s
}

func test_string_empty() test -> Expected("") {
    let s: string = ""
    return s
}

func test_string_multiline() test -> Expected("hi") {
    let s: string = `hi`
    return s
}