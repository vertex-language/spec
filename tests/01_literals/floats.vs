package literals_test
build test

func test_float_simple() test -> Expected("3.140000") {
    var x: float = 3.14
    return x
}

func test_float_exponent_pos() test -> Expected("125.000000") {
    var x: float = 1.25e2
    return x
}

func test_float_exponent_neg() test -> Expected("0.012500") {
    var x: float = 1.25e-2
    return x
}

func test_float_exponent_uppercase() test -> Expected("125.000000") {
    var x: float = 1.25E2
    return x
}

func test_float_hex_exp_pos() test -> Expected("60.000000") {
    var x: float = 0xFp2
    return x
}

func test_float_hex_exp_neg() test -> Expected("3.750000") {
    var x: float = 0xFp-2
    return x
}