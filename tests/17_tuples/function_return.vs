package tuples_test
build test

func minMax(values: [int32]) -> (min: int32, max: int32) {
    var mn: int32 = values[0]
    var mx: int32 = values[0]
    for v in values {
        if v < mn { mn = v }
        if v > mx { mx = v }
    }
    return (mn, mx)
}

func divmod(a: int32, b: int32) -> (int32, int32) {
    return (a / b, a % b)
}

func test_tuple_return_min() test -> Expected("1") {
    let nums = [3, 1, 4, 1, 5]
    let (lo, hi) = minMax(values: nums)
    return lo
}

func test_tuple_return_max() test -> Expected("5") {
    let nums = [3, 1, 4, 1, 5]
    let (lo, hi) = minMax(values: nums)
    return hi
}

func test_divmod_quotient() test -> Expected("3") {
    let (q, r) = divmod(a: 10, b: 3)
    return q
}

func test_divmod_remainder() test -> Expected("1") {
    let (q, r) = divmod(a: 10, b: 3)
    return r
}

func test_divmod_even() test -> Expected("0") {
    let (q, r) = divmod(a: 10, b: 2)
    return r    // no remainder
}