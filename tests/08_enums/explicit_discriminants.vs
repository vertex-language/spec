package enums_test
build test

enum Status : int32 {
    Inactive = 0,
    Active   = 1,
    Pending  = 2,
}

func test_discriminant_as_int32() test -> Expected(int32, "1") {
    let s = Status.Active
    return s as int32
}

func test_discriminant_pending_value() test -> Expected(int32, "2") {
    let s = Status.Pending
    return s as int32
}

enum HttpMethod : uint8 {
    Get    = 0,
    Post,
    Put,
    Delete,
}

func test_implicit_sequential_discriminant() test -> Expected(int32, "1") {
    // Post has no explicit value, so it follows Get(0) sequentially
    let m = HttpMethod.Post
    return int32(m as uint8)
}

func test_implicit_sequential_discriminant_third() test -> Expected(int32, "2") {
    let m = HttpMethod.Put
    return int32(m as uint8)
}

func test_implicit_sequential_discriminant_fourth() test -> Expected(int32, "3") {
    let m = HttpMethod.Delete
    return int32(m as uint8)
}

enum ErrorCode : uint16 {
    None    = 0,
    Timeout = 408,
    Denied  = 403,
    Missing = 404,
    Crash,
}

func test_explicit_discriminant_value() test -> Expected(int32, "408") {
    let code = ErrorCode.Timeout
    return int32(code as uint16)
}

func test_sequential_after_explicit() test -> Expected(int32, "405") {
    // Crash has no explicit value, so it follows the last explicit
    // discriminant (Missing = 404) sequentially
    let code = ErrorCode.Crash
    return int32(code as uint16)
}

func statusFromInt(n: int32) -> Status {
    switch n {
    case 0: return .Inactive
    case 1: return .Active
    case 2: return .Pending
    default: return .Inactive
    }
}

func test_function_returning_enum_from_int() test -> Expected(int32, "2") {
    let s = statusFromInt(2)
    return s as int32
}

func test_function_returning_enum_default_case() test -> Expected(int32, "0") {
    let s = statusFromInt(99)
    return s as int32
}