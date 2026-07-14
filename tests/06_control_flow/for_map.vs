package control_flow_test
build test

func test_for_map_sum_values() test -> Expected(int32, "3") {
    let config: map[string]int32 = {"debug": 1, "verbose": 2}
    var sum: int32 = 0
    for k, v in config {
        sum += v
    }
    return sum
}

func test_for_map_keys_count() test -> Expected(int32, "2") {
    let config: map[string]int32 = {"debug": 1, "verbose": 2}
    var count: int32 = 0
    for k in config.keys() {
        count += 1
    }
    return count
}

func test_for_map_values_count() test -> Expected(int32, "2") {
    let config: map[string]int32 = {"debug": 1, "verbose": 2}
    var count: int32 = 0
    for v in config.values() {
        count += 1
    }
    return count
}