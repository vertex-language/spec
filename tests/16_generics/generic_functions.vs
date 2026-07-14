package generics_test
build test

func pairOf[A, B](a: A, b: B) -> Pair[A, B] {
    return Pair[A, B]{first: a, second: b}
}

struct Pair[A, B] {
    first:  A
    second: B
}

func test_pairOf_construction() test -> Expected(int32, "3") {
    let p = pairOf(3, "x")
    return p.first
}

func lookup[K: comparable, V](m: map[K]V, k: K) -> (V, string) {
    let v = m[k]
    return v, ""
}

func test_lookup_generic_map_function() test -> Expected(int32, "1") {
    let m: map[string]int32 = {"a": 1, "b": 2}
    let v, err = lookup(m, "a")
    if err != "" {
        return -1
    }
    return v
}

func first[T](items: []T) -> (T, string) {
    if items.length == 0 {
        var zero: T
        return zero, "empty"
    }
    return items[0], ""
}

func test_first_nonempty() test -> Expected(int32, "1") {
    let nums = [1, 2, 3]
    let v, err = first(nums)
    if err != "" {
        return -1
    }
    return v
}

func test_first_empty_returns_error() test -> Expected(bool, "1") {
    var nums: []int32 = []
    let v, err = first(nums)
    return err != ""
}

func test_first_empty_returns_zero_value() test -> Expected(int32, "0") {
    var nums: []int32 = []
    let v, err = first(nums)
    return v
}