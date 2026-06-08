package classes_test
build test

class Animal {
    name:   string
    health: int32
}

func test_class_default_init_field() test -> Expected("100") {
    let a = Animal(name: "Rex", health: 100)
    defer a.delete()
    return a.health
}

func test_class_var_field_write() test -> Expected("50") {
    var a = Animal(name: "Rex", health: 100)
    defer a.delete()
    a.health = 50
    return a.health
}

func test_class_reference_shared() test -> Expected("50") {
    // Both a and b reference the same heap object
    var a = Animal(name: "Rex", health: 100)
    defer a.delete()
    var b = a
    b.health = 50
    return a.health    // visible through a since same object
}

func test_class_no_crash() test {
    let a = Animal(name: "Cat", health: 80)
    defer a.delete()
}