package generics_test
build test

func get[T](items: []T, i: int32) -> (T, string) {
    if i < 0 || i >= items.length {
        var zero: T
        return zero, "out of range"
    }
    return items[i], ""
}

func test_zero_value_in_range() test -> Expected(int32, "20") {
    let items = [10, 20, 30]
    let v, err = get(items, 1)
    if err != "" {
        return -1
    }
    return v
}

func test_zero_value_out_of_range_returns_error() test -> Expected(bool, "1") {
    let items = [10, 20, 30]
    let v, err = get(items, 9)
    return err != ""
}

func test_zero_value_out_of_range_returns_zero() test -> Expected(int32, "0") {
    let items = [10, 20, 30]
    let v, err = get(items, 9)
    return v
}

func test_zero_value_negative_index() test -> Expected(bool, "1") {
    let items = [10, 20, 30]
    let v, err = get(items, -1)
    return err != ""
}