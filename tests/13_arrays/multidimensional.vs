package arrays_test
build test

func test_2d_access_row0_col0() test -> Expected(float32, "0.000000") {
    let m: [[float32; 2]; 2] = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    return m[0][0]
}

func test_2d_access_row0_col1() test -> Expected(float32, "1.000000") {
    let m: [[float32; 2]; 2] = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    return m[0][1]
}

func test_2d_access_row1_col0() test -> Expected(float32, "1.000000") {
    let m: [[float32; 2]; 2] = [
        [0.0, 1.0],
        [1.0, 0.0],
    ]
    return m[1][0]
}

func test_2d_mutate_element() test -> Expected(int32, "99") {
    var grid: [[int32; 2]; 2] = [
        [1, 2],
        [3, 4],
    ]
    grid[1][1] = 99
    return grid[1][1]
}