package operators_test
build test

func test_eq_true() test -> Expected(bool, "1") {
    let a: int32 = 5
    let b: int32 = 5
    return a == b
}

func test_eq_false() test -> Expected(bool, "0") {
    let a: int32 = 5
    let b: int32 = 6
    return a == b
}

func test_neq() test -> Expected(bool, "1") {
    let a: int32 = 5
    let b: int32 = 6
    return a != b
}

func test_gt() test -> Expected(bool, "1") {
    let a: int32 = 6
    let b: int32 = 5
    return a > b
}

func test_lt() test -> Expected(bool, "0") {
    let a: int32 = 6
    let b: int32 = 5
    return a < b
}

func test_ge_equal() test -> Expected(bool, "1") {
    let a: int32 = 5
    let b: int32 = 5
    return a >= b
}

func test_le_equal() test -> Expected(bool, "1") {
    let a: int32 = 5
    let b: int32 = 5
    return a <= b
}

func test_string_eq() test -> Expected(bool, "1") {
    let a: string = "hi"
    let b: string = "hi"
    return a == b
}