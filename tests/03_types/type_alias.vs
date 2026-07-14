package types_test
build test

type size_t = uint64

func test_type_alias_roundtrip() test -> Expected(uint32, "100") {
    let s: size_t = 100
    return uint32(s)
}

func test_type_alias_is_underlying_type() test -> Expected(bool, "1") {
    let s: size_t = 5
    let u: uint64 = s
    return u == 5
}