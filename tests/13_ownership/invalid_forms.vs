package ownership_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func archive(w: var Widget) -> int32 {
    return w.id
}

func test_use_after_transfer() test -> Expected(error) {
    var w = Widget(id: 1)
    let final = w.transfer()
    let n = w.id
}

func test_transfer_outside_owning_position() test -> Expected(error) {
    var w = Widget(id: 1)
    w.transfer()
}

func test_transfer_in_if_condition() test -> Expected(error) {
    var w = Widget(id: 1)
    if w.transfer() { }
}

func both(a: var Widget, b: var Widget) {
}

func test_double_transfer_same_call() test -> Expected(error) {
    var w = Widget(id: 1)
    both(w.transfer(), w.transfer())
}

func test_copy_while_transferring_same_call() test -> Expected(error) {
    var w = Widget(id: 1)
    both(w.transfer(), w)
}

struct Widget2 {
    id: int32
}

func bothMut(a: mut Widget2, b: mut Widget2) {
}

func test_double_mut_same_binding() test -> Expected(error) {
    var w = Widget2{id: 1}
    bothMut(w, w)
}

func readAndMut(a: Widget2, b: mut Widget2) {
}

func test_read_while_exclusively_accessed() test -> Expected(error) {
    var w = Widget2{id: 1}
    readAndMut(w, w)
}

class ClassB2 {
    func mutateA(a: mut ClassA2) {
    }
}

class ClassA2 {
    b: ClassB2
}

func test_exclusive_access_overlaps_receiver() test -> Expected(error) {
    var a = ClassA2()
    a.b.mutateA(a)
}

func test_conditional_transfer_definite_error() test -> Expected(error) {
    var w = Widget(id: 1)
    let cond = true
    if cond {
        let x = w.transfer()
    }
    let n = w.id
}

func test_transfer_inside_loop_body() test -> Expected(error) {
    var w = Widget(id: 1)
    for i in 0..3 {
        let x = w.transfer()
    }
}