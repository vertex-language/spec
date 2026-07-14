package memory_test
build test

func test_at_reads_offset() test -> Expected(int32, "30") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 10)
    buf.setAt(1, 20)
    buf.setAt(2, 30)

    return buf.at(2)
}

func test_setAt_writes_offset() test -> Expected(int32, "77") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(3, 77)
    return buf.at(3)
}

func test_at_equivalent_to_deref_add() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    defer delete(buf)

    buf.setAt(2, 55)
    return buf.at(2) == &(buf.add(2))
}