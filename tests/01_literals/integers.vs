package literals_test
build test

func test_int_decimal() test -> Expected("42") {
    var x: int32 = 42
    return x
}

func test_int_negative() test -> Expected("-7") {
    var x: int32 = -7
    return x
}

func test_int_underscore_separator() test -> Expected("1000000") {
    var x: int32 = 1_000_000
    return x
}

func test_int_binary() test -> Expected("42") {
    var x: int32 = 0b101010
    return x
}

func test_int_octal() test -> Expected("42") {
    var x: int32 = 0o52
    return x
}

func test_int_hex_upper() test -> Expected("255") {
    var x: int32 = 0xFF
    return x
}

func test_int_hex_lower() test -> Expected("255") {
    var x: int32 = 0xff
    return x
}

func test_int_hex_simple() test -> Expected("42") {
    var x: int32 = 0x2A
    return x
}

func test_int_hex_underscore() test -> Expected("4660") {
    var x: int32 = 0x12_34
    return x
}