package variables_test
build test

func test_let_is_immutable() test -> Expected(error) {
    let x = 10
    x = 20
}

func test_let_cannot_bind_mut_param() test -> Expected(error) {
    let increment = func(n: mut int32) {
        n += 1
    }
    let x = 10
    increment(x)
}