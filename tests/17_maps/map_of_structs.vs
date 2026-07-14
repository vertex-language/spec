package maps_test
build test

struct Point {
    x: int32
    y: int32
}

func test_map_value_is_struct() test -> Expected(int32, "3") {
    let m: map[string]Point = {"origin": Point{x: 3, y: 4}}
    return m["origin"].x
}

func test_map_struct_value_second_field() test -> Expected(int32, "4") {
    let m: map[string]Point = {"origin": Point{x: 3, y: 4}}
    return m["origin"].y
}