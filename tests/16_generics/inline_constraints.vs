package generics_test
build test

func concat[S: ~[]E, E](a: S, b: S) -> S {
    var result: S = a
    for e in b {
        result.push(e)
    }
    return result
}

func test_inline_slice_constraint() test -> Expected(int32, "5") {
    let a = [1, 2]
    let b = [3, 4, 5]
    let c = concat(a, b)
    return c.length
}

func clamp[T: ~int32 | ~float64](v: T, lo: T, hi: T) -> T {
    if v < lo { return lo }
    if v > hi { return hi }
    return v
}

func test_inline_union_constraint() test -> Expected(int32, "10") {
    return clamp(15, 0, 10)
}

func test_inline_union_constraint_float() test -> Expected(float64, "0.000000") {
    return clamp(-5.0, 0.0, 10.0)
}