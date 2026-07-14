package generics_test
build test

func storeShared[T](x: T) -> T {
    return x
}

func test_shared_convention_bare_copy() test -> Expected(int32, "5") {
    let x: int32 = 5
    return storeShared(x)
}

func mutateGeneric[T](x: mut T) {
}

func readGeneric[T](x: T) -> T {
    return x
}

struct Widget {
    id: int32
}

func test_generic_shared_convention_struct() test -> Expected(int32, "3") {
    let w = Widget{id: 3}
    return readGeneric(w).id
}