package generics_test
build test

func zeroOf[T]() -> T {
    var z: T
    return z
}

func test_explicit_type_arg_required() test -> Expected(int32, "0") {
    let n = zeroOf[int32]()
    return n
}

func test_explicit_type_arg_bool() test -> Expected(bool, "0") {
    let b = zeroOf[bool]()
    return b
}

func test_explicit_type_arg_string() test -> Expected(string, "") {
    let s = zeroOf[string]()
    return s
}