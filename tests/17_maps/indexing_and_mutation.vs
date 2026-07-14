package maps_test
build test

func test_map_write_new_key() test -> Expected(int32, "1") {
    var config: map[string]int32 = {}
    config["debug"] = 1
    return config["debug"]
}

func test_map_write_multiple_keys() test -> Expected(int32, "0") {
    var config: map[string]int32 = {}
    config["debug"]   = 1
    config["verbose"] = 0
    return config["verbose"]
}

func test_map_overwrite_existing_key() test -> Expected(int32, "9") {
    var config: map[string]int32 = {"debug": 1}
    config["debug"] = 9
    return config["debug"]
}

func test_map_read_after_multiple_writes() test -> Expected(int32, "1") {
    var config: map[string]int32 = {}
    config["debug"]   = 1
    config["verbose"] = 0
    return config["debug"]
}