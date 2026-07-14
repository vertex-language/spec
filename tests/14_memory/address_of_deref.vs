package memory_test
build test

func test_address_of_and_dereference() test -> Expected(int32, "42") {
    var x: int32 = 42
    let p = &x          // address-of — int32 -> typed_ptr int32
    let v = &p           // dereference — typed_ptr int32 -> int32
    return v
}

func test_dereference_write_side() test -> Expected(int32, "99") {
    var x: int32 = 42
    let p = &x
    &p = 99              // dereference on the write side — writes through p
    return x
}

func test_dereference_reflects_original_mutation() test -> Expected(int32, "5") {
    var x: int32 = 0
    let p = &x
    x = 5
    return &p            // reading through p sees the write to x
}