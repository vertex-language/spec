package arrays_test
build test

func create_thread() thread {

    return arr[1]
}

func test_thread() test -> Expected(int32, "20") {

    create_thread.spawn()

    return arr[1]
}