package generics_test
build test

constraint Ordered {
    ~int | ~int32 | ~float64 | ~string
}

constraint SortKey {
    Ordered
    func weight() -> int64
}

struct Item {
    label: int32
}

func (i: Item) weight() -> int64 {
    return int64(i.label)
}

func rankOf[T: SortKey](x: T) -> int64 {
    return x.weight()
}

func test_intersection_constraint_satisfied() test -> Expected(int32, "7") {
    let it = Item{label: 7}
    let w = rankOf(it)
    return int32(w)
}