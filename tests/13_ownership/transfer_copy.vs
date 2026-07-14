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

func test_transfer_explicit() test -> Expected(int32, "1") {
    var w = Widget(id: 1)
    return archive(w.transfer())
}

func test_bare_call_copies_and_survives() test -> Expected(bool, "1") {
    var w = Widget(id: 1)
    archive(w)              // no .transfer() — deep copy
    return w.id == 1        // w still usable
}

func test_transfer_into_binding() test -> Expected(int32, "1") {
    var w = Widget(id: 1)
    let final = w.transfer()
    return final.id
}

func test_copy_into_binding_both_alive() test -> Expected(bool, "1") {
    var w = Widget(id: 1)
    let final = w.transfer()   // TRANSFER
    return final.id == 1
}

func test_bare_binding_copy_survives() test -> Expected(bool, "1") {
    var w = Widget(id: 1)
    let backup = w              // COPY — w survives
    return w.id == backup.id
}

func test_chained_transfers() test -> Expected(int32, "1") {
    var w = Widget(id: 1)
    var a = w.transfer()
    var b = a.transfer()
    return archive(b.transfer())
}

func test_copy_then_transfer_chain() test -> Expected(bool, "1") {
    var w = Widget(id: 1)
    var a = w              // COPY — w survives
    var b = a.transfer()   // TRANSFER — a dead, b owns copy

    return w.id == 1       // w untouched
}