package generics_test
build test

constraint Stringer {
    func toString() -> string
}

struct Point {
    x: int32
    y: int32
}

func (p: Point) toString() -> string {
    return "point"
}

func describe[T: Stringer](x: T) -> string {
    return x.toString()
}

func test_method_constraint_satisfied() test -> Expected(string, "point") {
    let p = Point{x: 1, y: 2}
    return describe(p)
}