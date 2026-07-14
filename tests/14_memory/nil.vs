package memory_test
build test

func test_nil_default_declaration() test -> Expected(bool, "1") {
    var p: typed_ptr int32 = nil
    return p == nil
}

func test_nil_returned_on_new_failure_pattern() test -> Expected(bool, "1") {
    // failure returns nil paired with a non-empty error string (§13, §11.1)
    let buf, err = new[uint8](1024)
    if err != "" {
        return buf == nil
    }
    defer delete(buf)
    return buf != nil
}

func test_addr_on_nil_holding_binding_is_fine() test -> Expected(bool, "1") {
    var p: typed_ptr int32 = nil
    let pp = addr(p)   // addresses the slot, not the pointee — legal
    return pp != nil
}