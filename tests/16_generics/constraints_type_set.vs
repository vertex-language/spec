package generics_test
build test

import "builtins/constraints"

func min[T: constraints.Ordered](a: T, b: T) -> T {
    if a < b { return a }
    return b
}

func test_min_int() test -> Expected(int32, "3") {
    return min(3, 5)
}

func test_min_float() test -> Expected(float64, "2.710000") {
    return min(3.14, 2.71)
}

func test_min_string() test -> Expected(string, "apple") {
    return min("banana", "apple")
}

func test_min_explicit_type_arg() test -> Expected(float64, "2.710000") {
    return min[float64](3.14, 2.71)
}

constraint Ordered {
    ~int | ~int8 | ~int16 | ~int32 | ~int64 |
    ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 |
    ~float32 | ~float64 | ~string
}

func clampLocal[T: Ordered](v: T, lo: T, hi: T) -> T {
    if v < lo { return lo }
    if v > hi { return hi }
    return v
}

func test_custom_ordered_constraint() test -> Expected(int32, "10") {
    return clampLocal(15, 0, 10)
}

type Celsius = float32

func test_underlying_type_alias_satisfies_tilde_constraint() test -> Expected(float32, "5.000000") {
    let c: Celsius = 5.0
    return min(c, 10.0)
}