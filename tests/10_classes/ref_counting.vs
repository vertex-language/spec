package classes_test
build test

class Widget {
    id: int32
}

func test_new_basic_no_crash() test -> Expected(int32, "5") {
    let a = Widget(id: 5).new()
    return a.id
    // a drops to 0 refs, freed automatically
}

func test_new_shared_ref() test -> Expected(int32, "99") {
    let a = Widget(id: 99).new()
    let b = a           // b shares ownership, count = 2
    return a.id
    // b drops: count = 1; a drops: count = 0, freed
}

func test_weak_ref_while_owner_alive() test -> Expected(int32, "42") {
    let a = Widget(id: 42).new()
    weak let b = a      // non-owning reference, count stays 1
    if let widget = b {
        return widget.id
    }
    return -1
}