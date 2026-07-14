package generics_test
build test

class Box[T] {
    value: T
}

func (b: Box[T]) init(value: T) {
    b.value = value
}

func (b: Box[T]) get() -> T {
    return b.value
}

func test_receiver_binds_type_param() test -> Expected(int32, "9") {
    let b = Box[int32](value: 9)
    return b.get()
}

func test_receiver_binds_type_param_string() test -> Expected(string, "hi") {
    let b = Box[string](value: "hi")
    return b.get()
}