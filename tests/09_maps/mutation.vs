package maps_test
build test

func test_map_set_key() test -> Expected("99") {
    var m = map[string]int32()
    defer m.delete()
    m["debug"] = 99
    return m["debug"] ?? 0
}

func test_map_overwrite_key() test -> Expected("2") {
    var m = map[string]int32()
    defer m.delete()
    m["key"] = 1
    m["key"] = 2
    return m["key"] ?? 0
}

func test_map_remove_key() test -> Expected("-1") {
    var m = map[string]int32()
    defer m.delete()
    m["key"] = 5
    m["key"] = nil
    return m["key"] ?? -1
}

func test_map_multiple_keys() test -> Expected("30") {
    var m = map[string]int32()
    defer m.delete()
    m["a"] = 10
    m["b"] = 20
    m["c"] = 30
    return m["c"] ?? 0
}

func test_map_empty_access() test -> Expected("-1") {
    var m = map[string]int32()
    defer m.delete()
    return m["missing"] ?? -1
}