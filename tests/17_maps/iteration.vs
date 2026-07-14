package maps_test
build test

func test_iterate_key_value_sum() test -> Expected(int32, "3") {
    let config = {"a": 1, "b": 2}
    var sum: int32 = 0
    for k, v in config {
        sum += v
    }
    return sum
}

func test_iterate_keys_count() test -> Expected(int32, "2") {
    let config = {"a": 1, "b": 2}
    var count: int32 = 0
    for k in config.keys() {
        count += 1
    }
    return count
}

func test_iterate_values_count() test -> Expected(int32, "2") {
    let config = {"a": 1, "b": 2}
    var count: int32 = 0
    for v in config.values() {
        count += 1
    }
    return count
}

func test_iterate_values_sum() test -> Expected(int32, "30") {
    let config = {"a": 10, "b": 20}
    var sum: int32 = 0
    for v in config.values() {
        sum += v
    }
    return sum
}

func test_iterate_empty_map() test -> Expected(int32, "0") {
    let config: map[string]int32 = {}
    var count: int32 = 0
    for k, v in config {
        count += 1
    }
    return count
}