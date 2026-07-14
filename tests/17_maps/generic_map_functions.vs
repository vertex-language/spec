package maps_test
build test

func lookup[K: comparable, V](m: map[K]V, k: K) -> (V, string) {
    let v = m[k]
    return v, ""
}

func test_generic_lookup_returns_value() test -> Expected(int32, "1") {
    let m: map[string]int32 = {"a": 1, "b": 2}
    let v, err = lookup(m, "a")
    if err != "" {
        return -1
    }
    return v
}

func keys[K: comparable, V](m: map[K]V) -> []K {
    var result: []K = []
    for k in m.keys() {
        result.push(k)
    }
    return result
}

func test_generic_keys_length() test -> Expected(int32, "2") {
    let m: map[string]int32 = {"a": 1, "b": 2}
    let ks = keys(m)
    return ks.length
}

func test_map_int_keys() test -> Expected(string, "one") {
    let m: map[int32]string = {1: "one", 2: "two"}
    return m[1]
}