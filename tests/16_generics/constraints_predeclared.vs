package generics_test
build test

func keys[K: comparable, V](m: map[K]V) -> []K {
    var result: []K = []
    for k in m.keys() {
        result.push(k)
    }
    return result
}

func test_comparable_constraint_map_keys() test -> Expected(int32, "2") {
    let m: map[string]int32 = {"a": 1, "b": 2}
    let ks = keys(m)
    return ks.length
}

func acceptsAny[T](x: T) -> bool {
    return true
}

func test_any_constraint_accepts_anything() test -> Expected(bool, "1") {
    return acceptsAny("hello")
}

func equalCheck[T: comparable](a: T, b: T) -> bool {
    return a == b
}

func test_comparable_equality() test -> Expected(bool, "1") {
    return equalCheck(5, 5)
}