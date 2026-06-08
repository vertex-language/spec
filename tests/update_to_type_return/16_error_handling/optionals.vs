package error_handling_test
build test

func findUser(id: int32) -> string? {
    if id < 0 { return nil }
    return "user"
}

func test_optional_found() test -> Expected("user") {
    if let user = findUser(id: 1) {
        return user
    }
    return "not found"
}

func test_optional_not_found_nil() test -> Expected("not found") {
    if let user = findUser(id: -1) {
        return user
    }
    return "not found"
}

func test_optional_coalesce_default() test -> Expected("default") {
    let name = findUser(id: -1) ?? "default"
    return name
}

func test_optional_coalesce_value() test -> Expected("user") {
    let name = findUser(id: 5) ?? "default"
    return name
}