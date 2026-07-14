package tuples_test
build test

func test_tuple_type_annotation() test -> Expected(int32, "1") {
    let t: (int32, string) = (1, "a")
    return t.0
}

func test_tuple_type_annotation_second_field() test -> Expected(string, "a") {
    let t: (int32, string) = (1, "a")
    return t.1
}

func test_tuple_type_annotation_three_floats() test -> Expected(float32, "1.000000") {
    let coords: (float32, float32, float32) = (0.0, 1.0, 0.0)
    return coords.1
}