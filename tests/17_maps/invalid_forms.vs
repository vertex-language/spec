package maps_test
build test

func test_map_key_type_mismatch() test -> Expected(error) {
    let m: map[string]int32 = {"a": 1}
    let v = m[5]
    // error: key type must match declared key type (string)
}

func test_map_value_type_mismatch() test -> Expected(error) {
    let m: map[string]int32 = {"a": "not a number"}
}

func test_map_key_not_comparable() test -> Expected(error) {
    struct NotComparable {
        data: []int32
    }
    let m: map[NotComparable]int32 = {}
    // error: map key type must satisfy `comparable`
}

func test_array_erase_not_valid() test -> Expected(error) {
    var items: []int32 = [1, 2, 3]
    items[0] = nil
    // error: `nil` erase is a map-only construct (foundation_spec §7)
}