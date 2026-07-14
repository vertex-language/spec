package arrays_test
build test

func test_fixed_array_index_out_of_declared_bounds_type_mismatch() test -> Expected(error) {
    var coords: [3]int32 = [10, 20, 30, 40]
    // error: literal has 4 elements, array type declares 3
}

func test_array_element_type_mismatch() test -> Expected(error) {
    let nums: []int32 = [1, "two", 3]
}

func test_array_index_with_non_integer() test -> Expected(error) {
    let items = [1, 2, 3]
    let bad = items["zero"]
}

func test_typed_map_style_erase_not_valid_on_array() test -> Expected(error) {
    var items: []int32 = [1, 2, 3]
    items[0] = nil
    // error: `nil` erase is a map-only construct (foundation_spec §7);
    //        arrays have no erase semantics
}

func test_slice_mutation_while_view_lives() test -> Expected(error) {
    var buf: []int32 = [1, 2, 3, 4, 5]
    let view = buf[0..3]
    buf.push(6)
    // error: Law of Exclusivity forbids mutating/transferring `buf`
    //        while the view `view` lives (foundation_spec §7)
}

func test_transfer_of_slice_view_while_alive() test -> Expected(error) {
    var buf: []int32 = [1, 2, 3, 4, 5]
    let view = buf[0..3]
    let moved = buf.transfer()
    // error: transferring `buf` while `view` still borrows it
}