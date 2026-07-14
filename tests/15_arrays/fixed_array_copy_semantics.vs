package arrays_test
build test

func test_fixed_array_bare_copy_is_independent() test -> Expected(bool, "1") {
    var a: [3]int32 = [1, 2, 3]
    var b = a
    b[0] = 99
    return a[0] == 1
}

struct Wrapper {
    data: [4]uint8
}

func test_fixed_array_embedded_in_struct_copies_inline() test -> Expected(bool, "1") {
    var w1 = Wrapper{data: [1, 2, 3, 4]}
    var w2 = w1
    w2.data[0] = 99
    return w1.data[0] == 1
}