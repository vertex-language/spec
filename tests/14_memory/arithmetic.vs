package memory_test
build test

func test_pointer_add_navigates_block() test -> Expected(int32, "20") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 10)
    buf.setAt(1, 20)
    buf.setAt(2, 30)

    let p2 = buf.add(1)
    return &p2
}

func test_pointer_sub_navigates_back() test -> Expected(int32, "10") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 10)
    buf.setAt(1, 20)

    let p2 = buf.add(1)
    let back = p2.sub(1)
    return &back
}

func test_reassigning_pointer_via_add() test -> Expected(int32, "30") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 10)
    buf.setAt(1, 20)
    buf.setAt(2, 30)

    var p = buf
    p = p.add(2)
    return &p
}

func test_one_past_end_is_legal_to_hold() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    let end = buf.add(4)   // legal to hold, not to dereference
    return end != buf
}