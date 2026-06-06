package classes_test
build test

class Node {
    val: int32
}

func test_identity_same_reference() test -> Expected("1") {
    var a = Node(val: 42)
    defer a.delete()
    let b = a           // b is a reference to the same object
    return a === b
}

func test_non_identity_same_reference() test -> Expected("0") {
    var a = Node(val: 42)
    defer a.delete()
    let b = a
    return a !== b
}

func test_identity_different_objects() test -> Expected("1") {
    var a = Node(val: 42)
    defer a.delete()
    var b = Node(val: 42)
    defer b.delete()
    return a !== b      // same value, different heap addresses
}

func test_non_identity_different_objects() test -> Expected("0") {
    var a = Node(val: 42)
    defer a.delete()
    var b = Node(val: 42)
    defer b.delete()
    return a === b
}