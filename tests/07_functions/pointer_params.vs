package functions_test
build test

func increment(n: *int32) {
    n += 1
}

func doubleVal(n: *int32) {
    n *= 2
}

func setTo(n: *int32, val: int32) {
    n = val
}

func swap(a: *int32, b: *int32) {
    let tmp = a
    a = b
    b = tmp
}

func test_pointer_increment() test -> Expected("6") {
    var x: int32 = 5
    increment(n: &x)
    return x
}

func test_pointer_double() test -> Expected("10") {
    var x: int32 = 5
    doubleVal(n: &x)
    return x
}

func test_pointer_set() test -> Expected("99") {
    var x: int32 = 0
    setTo(n: &x, val: 99)
    return x
}

func test_pointer_swap() test -> Expected("20") {
    var a: int32 = 10
    var b: int32 = 20
    swap(a: &a, b: &b)
    return a    // a should now hold 20
}

func test_pointer_swap_b() test -> Expected("10") {
    var a: int32 = 10
    var b: int32 = 20
    swap(a: &a, b: &b)
    return b    // b should now hold 10
}