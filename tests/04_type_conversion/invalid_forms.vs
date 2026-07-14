package type_conversion_test
build test

func test_bad_assign_string_to_int() test -> Expected(error) {
    let x: int32 = "hello"
}

func test_bad_cast_string_to_int() test -> Expected(error, "cannot convert string to int32") {
    let x: int32 = "hello" as int32
}

func test_bad_implicit_narrowing() test -> Expected(error) {
    let wide: int64 = 300
    let narrow: int8 = wide
}