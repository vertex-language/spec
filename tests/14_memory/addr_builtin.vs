package memory_test
build test

func test_addr_of_pointer_slot() test -> Expected(int32, "99") {
    var p: typed_ptr int32 = nil
    var x: int32 = 99
    p = &x

    let pp = addr(p)          // typed_ptr (typed_ptr int32)
    let inner = &pp             // dereferencing pp gives back p
    return &inner                // dereferencing p gives back x
}

func test_addr_write_through_redirects_p() test -> Expected(int32, "7") {
    var a: int32 = 7
    var b: int32 = 100
    var p: typed_ptr int32 = &a

    let pp = addr(p)
    &pp = &b                    // writes a new address into p, through pp
    return &p                   // p now points at b... but we check a's value differently
}