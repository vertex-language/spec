package classes_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func test_identity_same_binding() test -> Expected(bool, "1") {
    let w = Widget(id: 1)
    let w2 = w
    return w === w2
}

func test_identity_different_instances_same_data() test -> Expected(bool, "0") {
    let a = Widget(id: 1)
    let b = Widget(id: 1)
    return a === b
}

func test_not_identity_operator() test -> Expected(bool, "1") {
    let a = Widget(id: 1)
    let b = Widget(id: 1)
    return a !== b
}

func test_equal_data_but_not_identical() test -> Expected(bool, "1") {
    // classes have no `==` by default in this grammar's scalar-only
    // comparison surface, so equivalence here is checked field-by-field
    let a = Widget(id: 5)
    let b = Widget(id: 5)
    return a.id == b.id
}