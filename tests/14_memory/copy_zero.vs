package memory_test
build test

func test_copy_between_blocks() test -> Expected(int32, "5") {
    let src, err1 = new[int32](4)
    if err1 != "" {
        return -1
    }
    defer delete(src)
    let dst, err2 = new[int32](4)
    if err2 != "" {
        return -1
    }
    defer delete(dst)

    src.setAt(0, 5)
    copy(dst, src, 1)
    return dst.at(0)
}

func test_copy_multiple_elements() test -> Expected(int32, "30") {
    let src, err1 = new[int32](4)
    if err1 != "" {
        return -1
    }
    defer delete(src)
    let dst, err2 = new[int32](4)
    if err2 != "" {
        return -1
    }
    defer delete(dst)

    src.setAt(0, 10)
    src.setAt(1, 20)
    src.setAt(2, 30)
    copy(dst, src, 3)
    return dst.at(2)
}

func test_zero_clears_written_memory() test -> Expected(int32, "0") {
    let buf, err = new[uint8](1024)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 0xFF)
    zero(buf, 1024)
    return int32(buf.at(0))
}

func test_zero_only_clears_requested_count() test -> Expected(int32, "9") {
    let buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 1)
    buf.setAt(1, 9)
    zero(buf, 1)         // only clears element 0
    return buf.at(1)
}