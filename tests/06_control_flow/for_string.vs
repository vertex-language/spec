package control_flow_test
build test

func test_for_string_scalar_count() test -> Expected(int32, "5") {
    var count: int32 = 0
    for c in "héllo" {
        count += 1
    }
    return count
}

func test_for_string_byte_count() test -> Expected(int32, "6") {
    // 'é' is 2 UTF-8 bytes, so byte iteration sees one more than
    // scalar iteration does
    var count: int32 = 0
    for b in "héllo".bytes() {
        count += 1
    }
    return count
}

func test_for_string_ascii_scalar_and_byte_match() test -> Expected(bool, "1") {
    var scalarCount: int32 = 0
    for c in "hello" {
        scalarCount += 1
    }
    var byteCount: int32 = 0
    for b in "hello".bytes() {
        byteCount += 1
    }
    return scalarCount == byteCount
}