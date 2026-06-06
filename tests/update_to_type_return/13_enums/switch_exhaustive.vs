package enums_test
build test

enum Fruit {
    case apple, banana, cherry
}

enum Coin {
    case penny, nickel, dime, quarter
}

func coinValue(c: Coin) -> int32 {
    switch c {
    case .penny:   return 1
    case .nickel:  return 5
    case .dime:    return 10
    case .quarter: return 25
    }
}

func test_exhaustive_no_default_needed() test -> Expected("banana") {
    let f = Fruit.banana
    switch f {
    case .apple:  return "apple"
    case .banana: return "banana"
    case .cherry: return "cherry"
    }
}

func test_exhaustive_context_type() test -> Expected("cherry") {
    let f: Fruit = .cherry
    switch f {
    case .apple:  return "apple"
    case .banana: return "banana"
    case .cherry: return "cherry"
    }
}

func test_coin_penny() test -> Expected("1") {
    return coinValue(c: .penny)
}

func test_coin_quarter() test -> Expected("25") {
    return coinValue(c: .quarter)
}

func test_coin_dime() test -> Expected("10") {
    return coinValue(c: .dime)
}