package memory_test
build test

func test_new_zeroed_by_default() test -> Expected(int32, "0") {
    let buf, err = new[uint8](1024)
    if err != "" {
        return -1
    }
    defer delete(buf)
    return int32(buf.at(0))
}

func test_new_zero_false_then_written() test -> Expected(int32, "5") {
    let buf, err = new[int32](4, zero: false)
    if err != "" {
        return -1
    }
    defer delete(buf)
    buf.setAt(0, 5)          // must write before read per §11.1
    return buf.at(0)
}

func test_new_aligned_allocation_succeeds() test -> Expected(bool, "1") {
    let simdBuf, err = new[float32](16, align: 32)
    if err != "" {
        return false
    }
    defer delete(simdBuf)
    return simdBuf != nil
}

func test_new_aligned_and_unzeroed_combo() test -> Expected(int32, "1") {
    let simdScratch, err = new[float32](16, align: 32, zero: false)
    if err != "" {
        return -1
    }
    defer delete(simdScratch)
    simdScratch.setAt(0, 1.0)
    return int32(simdScratch.at(0))
}

func test_new_inferred_type_from_binding() test -> Expected(int32, "0") {
    var buf: typed_ptr uint8
    let err2: string
    buf, err2 = new(1024)   // T inferred as uint8 from buf
    if err2 != "" {
        return -1
    }
    defer delete(buf)
    return int32(buf.at(0))
}