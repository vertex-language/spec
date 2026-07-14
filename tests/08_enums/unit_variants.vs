package enums_test
build test

enum Direction {
    North,
    South,
    East,
    West,
}

func test_unit_variant_switch_match() test -> Expected(int32, "0") {
    let d = Direction.North
    var result: int32 = -1
    switch d {
    case .North:
        result = 0
    case .South:
        result = 1
    case .East:
        result = 2
    case .West:
        result = 3
    }
    return result
}

func test_unit_variant_implicit_member_annotation() test -> Expected(int32, "1") {
    let d2: Direction = .South
    var result: int32 = -1
    switch d2 {
    case .North:
        result = 0
    case .South:
        result = 1
    case .East:
        result = 2
    case .West:
        result = 3
    }
    return result
}

enum Permission {
    Read,
    Write,
    Execute,
}

func test_unit_variant_second_enum() test -> Expected(int32, "1") {
    let p = Permission.Write
    var result: int32 = -1
    switch p {
    case .Read:
        result = 0
    case .Write:
        result = 1
    case .Execute:
        result = 2
    }
    return result
}