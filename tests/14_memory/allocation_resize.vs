package memory_test
build test

func test_resize_preserves_existing_contents() test -> Expected(int32, "42") {
    var buf, err = new[uint8](64)
    if err != "" {
        return -1
    }
    buf.setAt(0, 42)

    let grown, err2 = resize(buf, 256)
    if err2 != "" {
        delete(buf)
        return -1
    }
    buf = grown
    defer delete(buf)
    return int32(buf.at(0))
}

func test_resize_grown_tail_is_zeroed() test -> Expected(int32, "0") {
    var buf, err = new[uint8](4)
    if err != "" {
        return -1
    }
    let grown, err2 = resize(buf, 8)
    if err2 != "" {
        delete(buf)
        return -1
    }
    buf = grown
    defer delete(buf)
    return int32(buf.at(6))   // in the newly grown region — zeroed
}

func test_resize_failure_leaves_original_valid() test -> Expected(int32, "9") {
    var buf, err = new[int32](4)
    if err != "" {
        return -1
    }
    buf.setAt(0, 9)

    // simulate checking the failure branch pattern; on real failure
    // buf remains valid and must still be freed (memory.md §11.3)
    let grown, err2 = resize(buf, 8)
    if err2 != "" {
        let stillValid = buf.at(0)
        delete(buf)
        return stillValid
    }
    defer delete(grown)
    return grown.at(0)
}