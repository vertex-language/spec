package literals_test
build test

func test_float_simple() test -> Expected(float, "3.14") {
    var x: float = 3.14
    return x
}

func test_float_exponent_pos() test -> Expected(float, "125") {
    var x: float = 1.25e2
    return x
}

func test_float_exponent_neg() test -> Expected(float, "0.0125") {
    var x: float = 1.25e-2
    return x
}

func test_float_exponent_uppercase() test -> Expected(float, "125") {
    var x: float = 1.25E2
    return x
}

func test_float_hex_exp_pos() test -> Expected(float, "60") {
    var x: float = 0xFp2
    return x
}

func test_float_hex_exp_neg() test -> Expected(float, "3.75") {
    var x: float = 0xFp-2
    return x
}