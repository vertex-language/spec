package enums_test
build test

enum Status: int {
    case inactive = 0
    case active   = 1
    case pending  = 2
}

enum Color: string {
    case red   = "red"
    case green = "green"
    case blue  = "blue"
}

enum Planet: string {
    case mercury
    case venus
    case earth
}

func test_raw_int_active() test -> Expected("1") {
    return Status.active.rawValue
}

func test_raw_int_inactive() test -> Expected("0") {
    return Status.inactive.rawValue
}

func test_raw_int_pending() test -> Expected("2") {
    return Status.pending.rawValue
}

func test_raw_string_explicit() test -> Expected("red") {
    return Color.red.rawValue
}

func test_raw_string_default_name() test -> Expected("mercury") {
    return Planet.mercury.rawValue
}

func test_raw_string_default_second() test -> Expected("earth") {
    return Planet.earth.rawValue
}

func test_from_raw_int_found() test -> Expected("1") {
    let s = Status(rawValue: 1)
    if let val = s {
        return val.rawValue
    }
    return -1
}

func test_from_raw_int_not_found() test -> Expected("-1") {
    let s = Status(rawValue: 99)
    if let val = s {
        return val.rawValue
    }
    return -1
}

func test_from_raw_string_found() test -> Expected("blue") {
    let c = Color(rawValue: "blue")
    if let col = c {
        return col.rawValue
    }
    return "none"
}