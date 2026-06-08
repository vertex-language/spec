package operators_test
build test

// ── integer widening ──────────────────────────────────────────────────────────

func test_as_int8_to_int32_positive() test -> Expected(int32, "100") {
    let x: int8 = 100
    return x as int32
}

func test_as_int8_to_int32_negative() test -> Expected(int32, "-1") {
    let x: int8 = -1
    return x as int32
}

func test_as_int32_to_int64_positive() test -> Expected(int64, "2147483647") {
    let x: int32 = 2147483647
    return x as int64
}

func test_as_int32_to_int64_negative() test -> Expected(int64, "-42") {
    let x: int32 = -42
    return x as int64
}

func test_as_uint8_to_uint32() test -> Expected(uint32, "255") {
    let x: uint8 = 255
    return x as uint32
}

func test_as_uint32_to_uint64() test -> Expected(uint64, "1000000") {
    let x: uint32 = 1000000
    return x as uint64
}

// ── integer narrowing ─────────────────────────────────────────────────────────

func test_as_int32_to_int8_fits() test -> Expected(int8, "127") {
    let x: int32 = 127
    return x as int8
}

func test_as_int32_to_int8_wraps() test -> Expected(int8, "-128") {
    let x: int32 = 128
    return x as int8
}

func test_as_int64_to_int32() test -> Expected(int32, "42") {
    let x: int64 = 42
    return x as int32
}

// ── float → int (truncate toward zero) ───────────────────────────────────────

func test_as_float32_to_int32_truncate_positive() test -> Expected(int32, "3") {
    let x: float32 = 3.9
    return x as int32
}

func test_as_float64_to_int32_truncate_positive() test -> Expected(int32, "3") {
    let x: float64 = 3.99
    return x as int32
}

func test_as_float32_to_int32_truncate_negative() test -> Expected(int32, "-3") {
    let x: float32 = -3.9
    return x as int32
}

func test_as_float64_to_int32_truncate_negative() test -> Expected(int32, "-3") {
    let x: float64 = -3.99
    return x as int32
}

func test_as_float64_to_int64_truncate() test -> Expected(int64, "100") {
    let x: float64 = 100.7
    return x as int64
}

// ── int → float ───────────────────────────────────────────────────────────────

func test_as_int32_to_float32() test -> Expected(float32, "7.000000") {
    let x: int32 = 7
    return x as float32
}

func test_as_int32_to_float64() test -> Expected(float64, "42.000000") {
    let x: int32 = 42
    return x as float64
}

func test_as_int64_to_float64() test -> Expected(float64, "1000000.000000") {
    let x: int64 = 1000000
    return x as float64
}

// ── float32 ↔ float64 ─────────────────────────────────────────────────────────

func test_as_float32_to_float64() test -> Expected(float64, "3.000000") {
    let x: float32 = 3.0
    return x as float64
}

func test_as_float64_to_float32() test -> Expected(float32, "2.500000") {
    let x: float64 = 2.5
    return x as float32
}

// ── chained casts (left-associative) ─────────────────────────────────────────

func test_as_chain_int8_int32_int64() test -> Expected(int64, "50") {
    let x: int8 = 50
    return x as int32 as int64
}

func test_as_chain_float64_int32_int64() test -> Expected(int64, "9") {
    let x: float64 = 9.8
    return x as int32 as int64
}

func test_as_chain_int32_float32_float64() test -> Expected(float64, "5.000000") {
    let x: int32 = 5
    return x as float32 as float64
}