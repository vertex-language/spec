package maps_test
build test

func test_map_literal_read() test -> Expected(int32, "1") {
    let somemap = {"a": 1, "b": 2}
    return somemap["a"]
}

func test_map_literal_second_key() test -> Expected(int32, "2") {
    let somemap = {"a": 1, "b": 2}
    return somemap["b"]
}

func test_typed_map_literal() test -> Expected(int32, "1") {
    let typedMap: map[string]int32 = {"a": 1, "b": 2}
    return typedMap["a"]
}

func test_empty_map_literal() test -> Expected(int32, "0") {
    var config: map[string]int32 = {}
    config["x"] = 5
    return config["x"] - 5
}