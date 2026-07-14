package memory_test
build test

func test_sizeof_int32() test -> Expected(int32, "4") {
    let s = sizeof(int32)
    return int32(s)
}

func test_alignof_int32() test -> Expected(int32, "4") {
    let a = alignof(int32)
    return int32(a)
}

struct Point {
    x: int32
    y: int32
}

func test_sizeof_struct() test -> Expected(int32, "8") {
    let s2 = sizeof(Point)
    return int32(s2)
}