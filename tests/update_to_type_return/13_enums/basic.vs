package enums_test
build test

enum Direction {
    case north
    case south
    case east
    case west
}

enum Permission {
    case read, write, execute
}

func test_enum_switch_north() test -> Expected("north") {
    let d = Direction.north
    switch d {
    case .north: return "north"
    case .south: return "south"
    case .east:  return "east"
    case .west:  return "west"
    }
}

func test_enum_switch_west() test -> Expected("west") {
    let d = Direction.west
    switch d {
    case .north: return "north"
    case .south: return "south"
    case .east:  return "east"
    case .west:  return "west"
    }
}

func test_enum_equality_same() test -> Expected("1") {
    let a = Direction.south
    let b = Direction.south
    return a == b
}

func test_enum_equality_different() test -> Expected("0") {
    let a = Direction.north
    let b = Direction.south
    return a == b
}

func test_enum_inequality() test -> Expected("1") {
    let a = Direction.north
    return a != Direction.east
}

func test_enum_context_inference() test -> Expected("write") {
    let p: Permission = .write
    switch p {
    case .read:    return "read"
    case .write:   return "write"
    case .execute: return "execute"
    }
}