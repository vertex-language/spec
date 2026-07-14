package memory_test
build test

func test_pointer_equality_same_binding() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    let alias = buf
    return buf == alias
}

func test_pointer_inequality_different_offsets() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    let p2 = buf.add(1)
    return buf != p2
}

func test_pointer_ordering_same_block() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    let p2 = buf.add(2)
    return buf < p2
}

func test_pointer_ordering_le_ge() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    let p2 = buf.add(2)
    return p2 >= buf && buf <= p2
}

func test_pointer_equality_against_nil() test -> Expected(bool, "1") {
    var p: typed_ptr int32 = nil
    return p == nil
}

func test_pointer_inequality_against_nil() test -> Expected(bool, "1") {
    let buf, err = new[int32](1)
    if err != "" {
        return false
    }
    defer delete(buf)
    return buf != nil
}