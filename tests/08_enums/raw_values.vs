package enums_test
build test

enum Status : int32 {
    Inactive = 0,
    Active   = 1,
    Pending  = 2,
}

enum HttpCode : uint16 {
    Ok      = 200,
    Created = 201,
    NotFound = 404,
    Crash,      // 405
}

func statusFromRaw(n: int32) -> Status? {
    switch n {
    case 0: return .Inactive
    case 1: return .Active
    case 2: return .Pending
    default: return nil
    }
}

func test_raw_int_active() test -> Expected(int32, "1") {
    return Status.Active as int32
}

func test_raw_int_inactive() test -> Expected(int32, "0") {
    return Status.Inactive as int32
}

func test_raw_int_pending() test -> Expected(int32, "2") {
    return Status.Pending as int32
}

func test_raw_uint16_not_found() test -> Expected(uint32, "404") {
    return HttpCode.NotFound as uint16
}

func test_raw_uint16_auto_increment() test -> Expected(uint32, "405") {
    return HttpCode.Crash as uint16
}

func test_from_raw_int_found() test -> Expected(int32, "1") {
    let s = statusFromRaw(n: 1)
    if let val = s {
        return val as int32
    }
    return -1
}

func test_from_raw_int_not_found() test -> Expected(int32, "-1") {
    let s = statusFromRaw(n: 99)
    if let val = s {
        return val as int32
    }
    return -1
}

func test_from_raw_zero() test -> Expected(int32, "0") {
    let s = statusFromRaw(n: 0)
    if let val = s {
        return val as int32
    }
    return -1
}