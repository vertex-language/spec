package error_handling_test
build test

func addInts(a: int32, b: int32) -> int32 {
    return a + b
}

func test_bad_add() test -> Expected(error) {
    return addInts(a: 10, b: "5")
}

func test_bad_assign() test -> Expected(error) {
    let x: int32 = "hello"
}

func test_bad_cast() test -> Expected(error, "cannot convert string to int32") {
    let x: int32 = "hello" as int32
}

struct Point {
    x: int32
    y: int32
}

func test_bad_field() test -> Expected(error, "no field 'z' on Point") {
    let p = Point{x: 0, y: 0}
    let n = p.z
}

func mustCheckError() -> (int32, string) {
    return 0, "always fails"
}

func test_ignoring_error_is_not_a_compile_error() test -> Expected(int32, "0") {
    // the convention is explicit-over-automatic (foundation.md §35.5) —
    // nothing forces a check, so using the value without checking `err`
    // compiles fine and simply yields the zero value here
    let n, err = mustCheckError()
    return n
}