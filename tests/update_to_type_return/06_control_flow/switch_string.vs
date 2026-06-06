package control_flow_test
build test

func test_switch_string_first() test -> Expected("hello") {
    let s: string = "hello"
    switch s {
    case "hello":
        return "hello"
    case "world":
        return "world"
    default:
        return "other"
    }
}

func test_switch_string_second() test -> Expected("world") {
    let s: string = "world"
    switch s {
    case "hello":
        return "hello"
    case "world":
        return "world"
    default:
        return "other"
    }
}

func test_switch_string_default() test -> Expected("other") {
    let s: string = "foo"
    switch s {
    case "hello":
        return "hello"
    case "world":
        return "world"
    default:
        return "other"
    }
}