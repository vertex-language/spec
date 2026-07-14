package memory_test
build test

func test_pointer_declaration_and_alloc() test -> Expected(int32, "0") {
    let buf, err = new[int32](1)
    if err != "" {
        return -1
    }
    defer delete(buf)
    return buf.at(0)   // zeroed by default (memory.md §11.1)
}

func test_pointer_write_and_read() test -> Expected(int32, "42") {
    let buf, err = new[int32](1)
    if err != "" {
        return -1
    }
    defer delete(buf)
    buf.setAt(0, 42)
    return buf.at(0)
}

func test_pointer_thin_bare_copy_is_alias() test -> Expected(bool, "1") {
    let buf, err = new[int32](1)
    if err != "" {
        return false
    }
    defer delete(buf)
    buf.setAt(0, 5)

    let alias = buf          // bare copy — register move, same address
    alias.setAt(0, 9)
    return buf.at(0) == 9    // both point at the same block
}