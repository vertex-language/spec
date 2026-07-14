package memory_test
build test

func test_cast_typed_ptr_reinterpret() test -> Expected(int32, "255") {
    let buf, err = new[uint32](1)
    if err != "" {
        return -1
    }
    defer delete(buf)

    buf.setAt(0, 0x000000FF)
    let raw: typed_ptr uint8 = buf as typed_ptr uint8
    return int32(raw.at(0))    // low byte on a little-endian read
}

func test_cast_pointer_to_integer_and_back() test -> Expected(bool, "1") {
    let buf, err = new[int32](1)
    if err != "" {
        return false
    }
    defer delete(buf)

    let addrVal: uint64 = buf as uint64
    let back: typed_ptr int32 = addrVal as typed_ptr int32
    return back == buf
}

func test_cast_inferred_target() test -> Expected(bool, "1") {
    let buf, err = new[int32](1)
    if err != "" {
        return false
    }
    defer delete(buf)

    let auto: typed_ptr uint8 = buf    // target known — `as` inferred
    return auto != nil
}