package classes_test
build test

class Animal {
    name: string
}

func (a: Animal) init(name: string) {
    a.name = name
}

func (a: Animal) deinit() {
}

func test_class_construction() test -> Expected(string, "Rex") {
    let a = Animal(name: "Rex")
    return a.name
}

class Counter {
    value: int32
}

func (c: Counter) init(start: int32) {
    c.value = start
}

func test_class_init_sets_field() test -> Expected(int32, "5") {
    let c = Counter(start: 5)
    return c.value
}

var deinitCount: int32 = 0

class Tracked {
    id: int32
}

func (t: Tracked) init(id: int32) {
    t.id = id
}

func (t: Tracked) deinit() {
    deinitCount += 1
}

func test_deinit_runs_at_scope_exit() test -> Expected(int32, "1") {
    deinitCount = 0
    let makeAndDrop = func () {
        let t = Tracked(id: 1)
    }
    makeAndDrop()
    return deinitCount
}