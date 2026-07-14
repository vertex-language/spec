package maps_test
build test

func test_map_erase_via_nil() test -> Expected(bool, "1") {
    var config: map[string]int32 = {"debug": 1}
    config["debug"] = nil
    let count = config.keys()
    return count.length == 0
}

func test_map_erase_leaves_other_keys() test -> Expected(int32, "0") {
    var config: map[string]int32 = {"debug": 1, "verbose": 0}
    config["debug"] = nil
    return config["verbose"]
}

func test_map_erase_then_rewrite() test -> Expected(int32, "5") {
    var config: map[string]int32 = {"debug": 1}
    config["debug"] = nil
    config["debug"] = 5
    return config["debug"]
}