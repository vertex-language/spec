package literals_test
build test

func test_string_let() test -> Expected(string, "hello") {
    let s: string = "hello"
    return s
}

func test_string_var() test -> Expected(string, "world") {
    var s: string = "world"
    return s
}

func test_string_empty() test -> Expected(string, "") {
    let s: string = ""
    return s
}

func test_string_multiline() test -> Expected(string, "hi") {
    let s: string = `hi`
    return s
}