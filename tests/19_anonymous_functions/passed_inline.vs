package anonymous_functions_test
build test

func inline_process(nums: []int32, f: func(int32) -> int32) -> []int32 {
    var result: []int32 = []
    for n in nums {
        result.push(f(n))
    }
    return result
}

func test_higher_order_inline_call() test -> Expected(int32, "4") {
    let nums = [1, 2, 3]
    let doubled = inline_process(nums, func(n: int32) -> int32 {
        return n * 2
    })
    return doubled[1]
}

class inline_Emitter {
    handler: func(int32) -> int32
}

func (e: inline_Emitter) init() {
}

func (e: mut inline_Emitter) on(f: func(int32) -> int32) {
    e.handler = f
}

func (e: inline_Emitter) fire(n: int32) -> int32 {
    return e.handler(n)
}

func test_callback_registration_pattern() test -> Expected(int32, "10") {
    var emitter = inline_Emitter()
    emitter.on(func(n: int32) -> int32 {
        return n * 2
    })
    return emitter.fire(5)
}