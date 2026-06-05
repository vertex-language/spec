package classes_test
build test

class Box {
    value: int32
    ready: bool
}

func (b: *Box) init(val: int32) {
    b.value = val
    b.ready = true
}

func (b: *Box) deinit() {
    b.ready = false
}

func test_init_sets_value() test -> Expected("42") {
    let b = Box(val: 42)
    defer b.delete()
    return b.value
}

func test_init_sets_bool_field() test -> Expected("1") {
    let b = Box(val: 10)
    defer b.delete()
    return b.ready
}

func test_deinit_no_crash() test {
    let b = Box(val: 1)
    b.delete()    // deinit runs here
}