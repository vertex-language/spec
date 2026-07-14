package memory_test
build test

func test_diff_same_block() test -> Expected(int32, "2") {
    let buf, err = new[int32](8)
    if err != "" {
        return -1
    }
    defer delete(buf)

    let p2 = buf.add(2)
    let n: int64 = p2.diff(buf)
    return int32(n)
}

func test_diff_is_signed() test -> Expected(int32, "-2") {
    let buf, err = new[int32](8)
    if err != "" {
        return -1
    }
    defer delete(buf)

    let p2 = buf.add(2)
    let n: int64 = buf.diff(p2)
    return int32(n)
}

func test_diff_against_one_past_end() test -> Expected(int32, "4") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    let end = buf.add(4)   // legal one-past-the-end address
    let n: int64 = end.diff(buf)
    return int32(n)
}