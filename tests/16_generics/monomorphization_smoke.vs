package generics_test
build test

import "builtins/constraints"

func identity[T](x: T) -> T {
    return x
}

func test_multiple_instantiations_independent() test -> Expected(bool, "1") {
    let a = identity(1)
    let b = identity("x")
    let c = identity(true)
    return a == 1 && b == "x" && c == true
}

func square[T: constraints.Number](x: T) -> T {
    return x * x
}

func test_constraint_checked_per_instantiation() test -> Expected(int32, "9") {
    return square(3)
}

func test_constraint_checked_per_instantiation_float() test -> Expected(float64, "6.250000") {
    return square(2.5)
}