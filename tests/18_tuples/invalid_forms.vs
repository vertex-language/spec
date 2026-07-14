package tuples_test
build test

func test_construction_without_parens_is_illegal() test -> Expected(error) {
    let t = 1, "a"
    // error: bare comma list constructs nothing at expression position —
    //        parens are required to construct a tuple literal (§29.1)
}

func test_single_element_tuple_without_trailing_comma() test -> Expected(error) {
    let single = (1)
    // this parses as a grouped expression (int32), not a one-element tuple —
    // (1,) is required (§29.1)
}

func test_destructure_with_wrong_arity() test -> Expected(error) {
    let t = (1, 2, 3)
    let a, b = t
    // error: destructuring arity mismatch
}

func test_field_named_access_on_positional_tuple() test -> Expected(error) {
    let t = (1, "a")
    let x = t.x
    // error: positional tuple has no named field `x`
}

func test_tuple_field_type_mismatch_in_annotation() test -> Expected(error) {
    let t: (int32, string) = ("a", 1)
    // error: field types swapped relative to annotation
}