package maps_test
build test

func test_map_literal_string_key() test -> Expected(int32, "1") {
    let m = {"a": 1, "b": 2}
    return m["a"] ?? -1
}

func test_map_literal_second_key() test -> Expected(int32, "2") {
    let m = {"a": 1, "b": 2}
    return m["b"] ?? -1
}

func test_map_missing_key_returns_nil() test -> Expected(int32, "-1") {
    let m = {"a": 1}
    return m["z"] ?? -1
}

func test_map_empty_write_read() test -> Expected(int32, "99") {
    var m: map[string]int32 = {}
    defer m.delete()
    m["x"] = 99
    return m["x"] ?? -1
}

func test_map_overwrite_key() test -> Expected(int32, "2") {
    var m: map[string]int32 = {"a": 1}
    defer m.delete()
    m["a"] = 2
    return m["a"] ?? -1
}

func test_map_delete_key() test -> Expected(int32, "-1") {
    var m: map[string]int32 = {"a": 1}
    defer m.delete()
    m["a"] = nil
    return m["a"] ?? -1
}

func test_map_int_key_string_value() test -> Expected(string, "hello") {
    let m = {1: "hello", 2: "world"}
    return m[1] ?? "none"
}

func test_map_multiple_writes() test -> Expected(int32, "3") {
    var m: map[string]int32 = {}
    defer m.delete()
    m["a"] = 1
    m["b"] = 2
    m["c"] = 3
    return m["c"] ?? -1
}