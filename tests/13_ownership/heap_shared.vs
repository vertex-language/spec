package ownership_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func inspect(w: Widget) -> int32 {
    return w.id
}

func test_shared_construction() test -> Expected(int32, "1") {
    var a = shared(Widget(id: 1))
    return a.id
}

func test_shared_handle_copy_is_refcount_bump() test -> Expected(bool, "1") {
    var a = shared(Widget(id: 1))
    var b = a
    return a === b
}

func test_shared_read_via_shared_access() test -> Expected(int32, "1") {
    var a = shared(Widget(id: 1))
    return inspect(a)
}

func rename(w: mut Widget, tag: int32) {
    w.id = tag
}

func test_shared_mutation_via_mut_param() test -> Expected(int32, "9") {
    var a = shared(Widget(id: 1))
    rename(a, 9)
    return a.id
}

func test_promotion_unique_value_to_shared() test -> Expected(int32, "2") {
    var u = Widget(id: 2)
    var s = shared(u)
    return s.id
}

func takeShared(w: shared Widget) -> int32 {
    return w.id
}

func test_shared_typed_binding() test -> Expected(int32, "3") {
    var a: shared Widget = shared(Widget(id: 3))
    return takeShared(a)
}