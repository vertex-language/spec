package ownership_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func test_unique_construction() test -> Expected(int32, "1") {
    var u = unique(Widget(id: 1))
    return u.id
}

func test_unique_transfer_is_cheap_and_moves() test -> Expected(int32, "1") {
    var u = unique(Widget(id: 1))
    var v = u.transfer()   // TRANSFER — O(1); u is dead
    return v.id
}

func take(w: unique Widget) -> int32 {
    return w.id
}

func test_unique_typed_binding() test -> Expected(int32, "5") {
    var u: unique Widget = unique(Widget(id: 5))
    return take(u.transfer())
}

func test_unique_field_mutation() test -> Expected(int32, "9") {
    var u = unique(Widget(id: 1))
    u.id = 9
    return u.id
}