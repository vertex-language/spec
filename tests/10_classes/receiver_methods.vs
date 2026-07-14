package classes_test
build test

class Point {
    x: int32
    y: int32
}

func (p: Point) init(x: int32, y: int32) {
    p.x = x
    p.y = y
}

func (p: Point) describe() -> int32 {
    return p.x
}

func (p: mut Point) reset() {
    p.x = 0
    p.y = 0
}

func test_shared_receiver_read() test -> Expected(int32, "3") {
    let p = Point(x: 3, y: 4)
    return p.describe()
}

func test_mut_receiver_mutates() test -> Expected(int32, "0") {
    var p = Point(x: 3, y: 4)
    p.reset()
    return p.x
}

func test_mut_receiver_mutates_both_fields() test -> Expected(int32, "0") {
    var p = Point(x: 3, y: 4)
    p.reset()
    return p.y
}

class Animal {
    name: string
}

func (a: Animal) init(name: string) {
    a.name = name
}

func (a: Animal) rename(newName: string) {
    a.name = newName
}

func test_named_param_receiver_call() test -> Expected(string, "Max") {
    let rex = Animal(name: "Rex")
    rex.rename(newName: "Max")
    return rex.name
}