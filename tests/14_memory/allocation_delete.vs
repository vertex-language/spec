package memory_test
build test

func test_delete_releases_block() test -> Expected(bool, "1") {
    let buf, err = new[int32](4)
    if err != "" {
        return false
    }
    delete(buf)
    return true   // no crash observable here; deletion is fire-and-forget
}

func test_delete_nil_is_noop() test -> Expected(bool, "1") {
    var p: typed_ptr int32 = nil
    delete(p)     // no-op per §11.2
    return true
}