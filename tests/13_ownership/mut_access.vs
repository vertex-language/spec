package ownership_test
build test

struct Widget {
    id: int32
}

func rename(w: mut Widget, tag: int32) {
    w.id = tag
}

func test_mut_param_mutates_original() test -> Expected(int32, "9") {
    var w = Widget{id: 1}
    rename(w, 9)
    return w.id
}

func increment(n: mut int32) {
    n += 1
}

func test_mut_scalar_param() test -> Expected(int32, "1") {
    var count: int32 = 0
    increment(count)
    return count
}

func (w: mut Widget) rename2(tag: int32) {
    w.id = tag
}

func test_mut_receiver_call_site_is_bare() test -> Expected(int32, "7") {
    var w = Widget{id: 1}
    w.rename2(7)
    return w.id
}

func test_mut_never_copies() test -> Expected(bool, "1") {
    var w = Widget{id: 1}
    w.rename2(7)
    // no copy was ever made — the same binding reflects the mutation
    return w.id == 7
}