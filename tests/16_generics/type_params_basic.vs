package generics_test
build test

func identity[T](x: T) -> T {
    return x
}

func test_identity_int() test -> Expected(int32, "5") {
    return identity(5)
}

func test_identity_string() test -> Expected(string, "hi") {
    return identity("hi")
}

func test_identity_explicit_type_arg() test -> Expected(int32, "9") {
    return identity[int32](9)
}

struct Pair[A, B] {
    first:  A
    second: B
}

func test_generic_struct_field_access() test -> Expected(int32, "1") {
    let p = Pair[int32, string]{first: 1, second: "a"}
    return p.first
}

func test_generic_struct_second_field() test -> Expected(string, "a") {
    let p = Pair[int32, string]{first: 1, second: "a"}
    return p.second
}