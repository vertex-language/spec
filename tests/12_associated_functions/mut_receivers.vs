package associated_functions_test
build test

struct Point {
    x: int32
    y: int32
}

func (p: mut Point) reset() {
    p.x = 0
    p.y = 0
}

func test_mut_receiver_struct_field() test -> Expected(int32, "0") {
    var p = Point{x: 3, y: 4}
    p.reset()
    return p.x
}

func (p: mut Point) translate(dx: int32, dy: int32) {
    p.x += dx
    p.y += dy
}

func test_mut_receiver_with_args() test -> Expected(int32, "13") {
    var p = Point{x: 3, y: 4}
    p.translate(dx: 10, dy: 10)
    return p.x
}

func test_mut_receiver_with_args_second_field() test -> Expected(int32, "14") {
    var p = Point{x: 3, y: 4}
    p.translate(dx: 10, dy: 10)
    return p.y
}