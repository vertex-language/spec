package associated_functions_test
build test

struct Point {
    x: int32
    y: int32
}

func (p: Point) describe() -> int32 {
    let n = p.x
    return n
}

func test_shared_receiver_struct() test -> Expected(int32, "3") {
    let p = Point{x: 3, y: 4}
    return p.describe()
}

func (p: Point) sum() -> int32 {
    return p.x + p.y
}

func test_shared_receiver_computed_result() test -> Expected(int32, "7") {
    let p = Point{x: 3, y: 4}
    return p.sum()
}

func test_shared_receiver_does_not_consume() test -> Expected(int32, "3") {
    let p = Point{x: 3, y: 4}
    p.describe()
    return p.x
}