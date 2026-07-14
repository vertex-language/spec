package ownership_test
build test

struct Widget {
    id: int32
}

func readAndReport(a: Widget) -> int32 {
    return a.id
}

func mutate(a: mut Widget) {
    a.id += 1
}

func test_sequential_mut_calls_are_fine() test -> Expected(int32, "3") {
    var w = Widget{id: 1}
    mutate(w)
    mutate(w)
    return w.id
}

func test_read_after_mut_call_sequential() test -> Expected(int32, "2") {
    var w = Widget{id: 1}
    mutate(w)
    return readAndReport(w)
}

class ClassB {
    tag: int32
}

func (b: ClassB) init(tag: int32) {
    b.tag = tag
}

func (b: mut ClassB) setTag(t: int32) {
    b.tag = t
}

class ClassA {
    b: ClassB
}

func (a: ClassA) init() {
    a.b = ClassB(tag: 0)
}

func test_disjoint_exclusive_access_is_fine() test -> Expected(int32, "9") {
    var a = ClassA()
    a.b.setTag(9)
    return a.b.tag
}