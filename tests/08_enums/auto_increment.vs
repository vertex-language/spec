package enums_test
build test

// No explicit values — auto-increments from 0
enum Level : int32 {
    Low,
    Mid,
    High,
}

// Partial explicit — anchored at 0 and 5, Urgent continues to 6
enum Priority : int32 {
    None   = 0,
    Normal = 5,
    Urgent,
}

func test_auto_increment_first() test -> Expected(int32, "0") {
    return Level.Low as int32
}

func test_auto_increment_second() test -> Expected(int32, "1") {
    return Level.Mid as int32
}

func test_auto_increment_third() test -> Expected(int32, "2") {
    return Level.High as int32
}

func test_auto_increment_after_explicit() test -> Expected(int32, "6") {
    return Priority.Urgent as int32
}