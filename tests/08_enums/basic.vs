package enums_test
build test

enum Direction {
    North,
    South,
    East,
    West,
}

enum Permission {
    Read, Write, Execute,
}

func directionEquals(a: Direction, b: Direction) -> bool {
    switch a {
    case .North: switch b { case .North: return true default: return false }
    case .South: switch b { case .South: return true default: return false }
    case .East:  switch b { case .East:  return true default: return false }
    case .West:  switch b { case .West:  return true default: return false }
    }
}

func test_enum_switch_north() test -> Expected(string, "north") {
    let d = Direction.North
    switch d {
    case .North: return "north"
    case .South: return "south"
    case .East:  return "east"
    case .West:  return "west"
    }
}

func test_enum_switch_west() test -> Expected(string, "west") {
    let d = Direction.West
    switch d {
    case .North: return "north"
    case .South: return "south"
    case .East:  return "east"
    case .West:  return "west"
    }
}

func test_enum_equality_same() test -> Expected(bool, "1") {
    let a = Direction.South
    let b = Direction.South
    return directionEquals(a: a, b: b)
}

func test_enum_equality_different() test -> Expected(bool, "0") {
    let a = Direction.North
    let b = Direction.South
    return directionEquals(a: a, b: b)
}

func test_enum_inequality() test -> Expected(bool, "1") {
    let a = Direction.North
    switch a {
    case .East: return false
    default:    return true
    }
}

func test_enum_context_inference() test -> Expected(string, "write") {
    let p: Permission = .Write
    switch p {
    case .Read:    return "read"
    case .Write:   return "write"
    case .Execute: return "execute"
    }
}