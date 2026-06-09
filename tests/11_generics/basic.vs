package generics_test
build test

func identity<T>(value: T) -> T {
    return value
}

struct Box<T> {
    value: T
}

func test_identity_int() test -> Expected(int32, "42") {
    return identity(value: 42)
}

func test_identity_string() test -> Expected(string, "hello") {
    return identity(value: "hello")
}

func test_identity_bool_true() test -> Expected(bool, "1") {
    return identity(value: true)
}

func test_identity_bool_false() test -> Expected(bool, "0") {
    return identity(value: false)
}

func test_box_int_value() test -> Expected(int32, "99") {
    let b = Box{value: 99}
    return b.value
}

func test_box_string_value() test -> Expected(string, "world") {
    let b = Box{value: "world"}
    return b.value
}