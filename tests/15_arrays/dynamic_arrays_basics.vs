package arrays_test
build test

func test_dynamic_array_empty_literal() test -> Expected(int32, "0") {
    var items: []int32 = []
    return items.length
}

func test_dynamic_array_typed_declaration() test -> Expected(int32, "0") {
    var players: []Player = []
    return players.length
}

struct Player {
    id: int32
}

func test_dynamic_array_inferred_literal() test -> Expected(int32, "3") {
    var scores = [10, 20, 30]
    return scores.length
}

func test_dynamic_array_string_elements() test -> Expected(string, "a") {
    var names: []string = ["a", "b"]
    return names[0]
}

func test_dynamic_array_byte_declaration() test -> Expected(int32, "0") {
    var buf: []uint8 = []
    return buf.length
}