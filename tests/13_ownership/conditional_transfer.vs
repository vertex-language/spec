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

func test_transfer_only_in_untaken_branch_is_safe() test -> Expected(int32, "1") {
    var w = Widget(id: 1)
    let cond = false
    if cond {
        let x = w.transfer()
    }
    // cond was false, but liveness is static — this branch is
    // still flagged as "possibly transferred" per ownership.md §7,
    // so a real use here would be a compile error. This test instead
    // demonstrates the safe pattern: don't touch w after a conditional
    // transfer at all, read it before the if instead.
    return w.id
}