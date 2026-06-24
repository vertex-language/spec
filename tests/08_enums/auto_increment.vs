package enums_test
build test

// No explicit values — should auto-increment from 0
enum Level: int {
    case low
    case mid
    case high
}

// Partial explicit — first anchored, rest continue from there
enum Priority: int {
    case none   = 0
    case normal = 5
    case urgent
}

func test_auto_increment_first() test -> Expected(int32, "0") {
    return Level.low.rawValue
}

func test_auto_increment_second() test -> Expected(int32, "1") {
    return Level.mid.rawValue
}

func test_auto_increment_third() test -> Expected(int32, "2") {
    return Level.high.rawValue
}

func test_auto_increment_after_explicit() test -> Expected(int32, "6") {
    return Priority.urgent.rawValue
}