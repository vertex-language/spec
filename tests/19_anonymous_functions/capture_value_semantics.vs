package anonymous_functions_test
build test

func test_capture_by_value() test -> Expected(int32, "9") {
    let factor: int32 = 3
    let multiply = func(n: int32) -> int32 {
        return n * factor
    }
    return multiply(3)
}

func test_capture_snapshot_at_creation() test -> Expected(int32, "6") {
    var factor: int32 = 3
    let multiply = func(n: int32) -> int32 {
        return n * factor
    }
    factor = 100   // mutated after closure creation
    return multiply(2)   // still uses the captured value of 3, not 100
}

func test_mutating_capture_is_compile_error() test -> Expected(error) {
    var count: int32 = 0
    let increment = func() {
        count += 1
        // error: captured copy, not the original — mutating it is
        //        a compile error (foundation.md §32)
    }
}