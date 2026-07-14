package types_test
build test

func test_annotated_int() test -> Expected(int32, "100") {
    let a: int = 100
    return int32(a)
}

func test_annotated_int8_bounds() test -> Expected(int32, "127") {
    let b: int8 = 127
    return int32(b)
}

func test_annotated_int16_bounds() test -> Expected(int32, "32767") {
    let c: int16 = 32767
    return int32(c)
}

func test_annotated_int32() test -> Expected(int32, "2147483647") {
    let d: int32 = 2147483647
    return d
}

func test_annotated_uint() test -> Expected(uint32, "100") {
    let f: uint = 100
    return uint32(f)
}

func test_annotated_uint8_bounds() test -> Expected(uint32, "255") {
    let g: uint8 = 255
    return uint32(g)
}

func test_annotated_uint16_bounds() test -> Expected(uint32, "65535") {
    let h: uint16 = 65535
    return uint32(h)
}

func test_annotated_float32() test -> Expected(float32, "3.140000") {
    let k: float32 = 3.14
    return k
}

func test_annotated_bool() test -> Expected(bool, "1") {
    let m: bool = true
    return m
}

func test_annotated_string() test -> Expected(string, "hello") {
    let n: string = "hello"
    return n
}