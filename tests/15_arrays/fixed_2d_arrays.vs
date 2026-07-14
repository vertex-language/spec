package arrays_test
build test

func test_2d_fixed_array_literal() test -> Expected(float32, "1.000000") {
    let matrix: [2][2]float32 = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    return matrix[0][1]
}

func test_2d_fixed_array_second_row() test -> Expected(float32, "1.000000") {
    let matrix: [2][2]float32 = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    return matrix[1][0]
}

func test_2d_fixed_array_mutation() test -> Expected(float32, "9.000000") {
    var matrix: [2][2]float32 = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    matrix[0][0] = 9.0
    return matrix[0][0]
}