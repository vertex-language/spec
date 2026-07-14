package associated_functions_test
build test

class Widget {
    id: int32
}

func (w: Widget) init(id: int32) {
    w.id = id
}

func (w: var Widget) consumeAndReturnId() -> int32 {
    return w.id
}

func test_owning_receiver_bare_transfers_unconditionally() test -> Expected(int32, "5") {
    let w = Widget(id: 5)
    return w.consumeAndReturnId()
}

func test_owning_receiver_copy_first_keeps_original() test -> Expected(bool, "1") {
    var w = Widget(id: 5)
    let backup = w              // COPY
    let result = backup.consumeAndReturnId()   // transfers the copy
    return w.id == 5            // w still alive
}