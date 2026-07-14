package classes_test
build test

class Widget {
    id:  int32
    tag: string
}

func (w: Widget) init(id: int32, tag: string) {
    w.id = id
    w.tag = tag
}

func test_class_field_read() test -> Expected(int32, "7") {
    let w = Widget(id: 7, tag: "a")
    return w.id
}

func test_class_field_read_second() test -> Expected(string, "a") {
    let w = Widget(id: 7, tag: "a")
    return w.tag
}

func test_class_field_mutation() test -> Expected(int32, "9") {
    var w = Widget(id: 7, tag: "a")
    w.id = 9
    return w.id
}

func test_class_copy_is_independent() test -> Expected(bool, "1") {
    var w = Widget(id: 7, tag: "a")
    var w2 = w
    w2.id = 99
    return w.id == 7
}