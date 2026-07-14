package enums_test
build test

enum Message {
    Quit,
    Move(int32, int32),
    Write(string),
    ChangeColor(uint8, uint8, uint8),
}

func test_mixed_unit_variant() test -> Expected(bool, "1") {
    let m = Message.Quit
    var matched = false
    switch m {
    case .Quit:
        matched = true
    case .Move(x, y):
    case .Write(s):
    case .ChangeColor(r, g, b):
    }
    return matched
}

func test_mixed_two_field_variant() test -> Expected(int32, "30") {
    let m = Message.Move(10, 20)
    var result: int32 = 0
    switch m {
    case .Quit:
    case .Move(x, y):
        result = x + y
    case .Write(s):
    case .ChangeColor(r, g, b):
    }
    return result
}

func test_mixed_string_variant() test -> Expected(string, "hello") {
    let m = Message.Write("hello")
    var result: string = ""
    switch m {
    case .Quit:
    case .Move(x, y):
    case .Write(s):
        result = s
    case .ChangeColor(r, g, b):
    }
    return result
}

enum NetworkEvent {
    Connected,
    Disconnected,
    Error(string),
}

func test_mixed_error_variant() test -> Expected(string, "timeout") {
    let e = NetworkEvent.Error("timeout")
    var result: string = ""
    switch e {
    case .Connected:
    case .Disconnected:
    case .Error(msg):
        result = msg
    }
    return result
}