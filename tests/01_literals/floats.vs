package literals_test
build test

func test_float32_simple() test -> Expected(float32, "3.140000") {
    var x: float32 = 3.14
    return x
}

func test_float32_exponent_pos() test -> Expected(float32, "125.000000") {
    var x: float32 = 1.25e2
    return x
}

func test_float32_exponent_neg() test -> Expected(float32, "0.012500") {
    var x: float32 = 1.25e-2
    return x
}

func test_float32_exponent_uppercase() test -> Expected(float32, "0.012500") {
    var x: float32 = 1.25E-2
    return x
}

func test_float32_hex_exp_pos() test -> Expected(float32, "60.000000") {
    var x: float32 = 0xFp2
    return x
}

func test_float32_hex_exp_neg() test -> Expected(float32, "3.750000") {
    var x: float32 = 0xFp-2
    return x
}