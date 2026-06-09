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

func test_init_sets_value() test -> Expected(int32, "42") {
    let b = Box(val: 42)
    defer b.delete()
    return b.value
}

func test_init_sets_bool_field() test -> Expected(int32, "1") {
    let b = Box(val: 10)
    defer b.delete()
    return b.ready
}