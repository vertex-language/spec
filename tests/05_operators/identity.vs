package operators_test
build test

class Widget {
    id: int32
}

func test_identity_same_binding() test -> Expected(bool, "1") {
    let w = Widget(id: 1)
    let w2 = w
    return w === w2
}

func test_identity_different_instances() test -> Expected(bool, "0") {
    let a = Widget(id: 1)
    let b = Widget(id: 1)
    return a === b
}

func test_not_identity() test -> Expected(bool, "1") {
    let a = Widget(id: 1)
    let b = Widget(id: 1)
    return a !== b
}

func test_identity_shared_handle() test -> Expected(bool, "1") {
    var a = shared(Widget(id: 1))
    var b = a
    return a === b
}