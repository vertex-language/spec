package enums_test
build test

enum Fruit {
    Apple, Banana, Cherry,
}

enum Coin {
    Penny, Nickel, Dime, Quarter,
}

func coinValue(c: Coin) -> int32 {
    switch c {
    case .Penny:   return 1
    case .Nickel:  return 5
    case .Dime:    return 10
    case .Quarter: return 25
    }
}

func test_exhaustive_no_default_needed() test -> Expected(string, "banana") {
    let f = Fruit.Banana
    switch f {
    case .Apple:  return "apple"
    case .Banana: return "banana"
    case .Cherry: return "cherry"
    }
}

func test_exhaustive_context_type() test -> Expected(string, "cherry") {
    let f: Fruit = .Cherry
    switch f {
    case .Apple:  return "apple"
    case .Banana: return "banana"
    case .Cherry: return "cherry"
    }
}

func test_coin_penny() test -> Expected(int32, "1") {
    return coinValue(c: .Penny)
}

func test_coin_quarter() test -> Expected(int32, "25") {
    return coinValue(c: .Quarter)
}

func test_coin_dime() test -> Expected(int32, "10") {
    return coinValue(c: .Dime)
}