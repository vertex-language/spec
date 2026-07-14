package control_flow_test
build test

enum Direction {
    North,
    South,
    East,
    West,
}

func test_switch_enum_case() test -> Expected(int32, "2") {
    let d = Direction.East
    var result: int32 = -1
    switch d {
    case .north:
    case .south:
    case .east:
        result = 2
    case .west:
    }
    return result
}

func test_switch_enum_implicit_member() test -> Expected(bool, "1") {
    let d: Direction = .South
    var matched = false
    switch d {
    case .North:
    case .South:
        matched = true
    case .East:
    case .West:
    }
    return matched
}