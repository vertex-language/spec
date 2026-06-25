package functions_test
build test

func add(a: int32, b: int32) -> int32 {
    return a + b
}

func multiply(a: int32, b: int32) -> int32 {
    return a * b
}

func isPositive(n: int32) -> bool {
    return n > 0
}

func max(a: int32, b: int32) -> int32 {
    if a > b {
        return a
    } else {
        return b
    }
}

func test_add_labeled() test -> Expected(int32, "15") {
    return add(a: 10, b: 5)
}

func test_add_positional() test -> Expected(int32, "7") {
    return add(3, 4)
}

func test_multiply() test -> Expected(int32, "50") {
    return multiply(a: 10, b: 5)
}

func test_is_positive_true() test -> Expected(bool, "1") {
    return isPositive(n: 5)
}

func test_is_positive_false() test -> Expected(bool, "0") {
    return isPositive(n: -1)
}

func test_is_positive_zero() test -> Expected(bool, "0") {
    return isPositive(n: 0)
}

func test_max_first_larger() test -> Expected(int32, "10") {
    return max(a: 10, b: 3)
}

func test_max_second_larger() test -> Expected(int32, "20") {
    return max(a: 7, b: 20)
}