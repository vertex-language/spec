package maps_test
build test

func test_map_literal_access_a() test -> Expected("1") {
    let m = {"a": 1, "b": 2}
    let val = m["a"]
    return val ?? -1
}

func test_map_literal_access_b() test -> Expected("2") {
    let m = {"a": 1, "b": 2}
    let val = m["b"]
    return val ?? -1
}

func test_map_missing_key_nil() test -> Expected("-1") {
    let m = {"a": 1, "b": 2}
    let val = m["c"]
    return val ?? -1
}

func test_map_typed_annotation() test -> Expected("42") {
    let m: map[string]int32 = {"x": 42}
    let val = m["x"]
    return val ?? 0
}

func test_map_access_returns_optional() test -> Expected("1") {
    let m = {"k": 5}
    let val = m["k"]
    return val != nil
}