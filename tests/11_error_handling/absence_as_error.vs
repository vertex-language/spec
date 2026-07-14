package error_handling_test
build test

struct User {
    id: int32
}

func findUser(id: int32) -> (User, string) {
    if id < 0 { return User{id: 0}, "not found" }
    return User{id: id}, ""
}

func test_found_returns_value() test -> Expected(int32, "5") {
    let user, err = findUser(id: 5)
    if err != "" {
        return -1
    }
    return user.id
}

func test_not_found_returns_error() test -> Expected(bool, "1") {
    let user, err = findUser(id: -1)
    return err != ""
}

func test_not_found_returns_zero_value() test -> Expected(int32, "0") {
    let user, err = findUser(id: -1)
    return user.id
}