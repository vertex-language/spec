package main
build linux

import "linux/lib/c"

class C : c {
    func printf(fmt:  ...*const char) -> int
}

// fibRecursive computes the nth Fibonacci number using classic recursion.
func fibRecursive(n: int32) -> int32 {
    if n <= 1 {
        return n
    }
    return fibRecursive(n - 1) + fibRecursive(n - 2)
}

// fibIterative computes the nth Fibonacci number in O(n) time and O(1) space.
func fibIterative(n: int32) -> int32 {
    if n <= 1 {
        return n
    }
    var a: int32 = 0
    var b: int32 = 1
    var i: int32 = 2
    while true {
        if i > n {
            break
        }
        var tmp: int32 = a + b
        a = b
        b = tmp
        i = i + 1
    }
    return b
}

func main() -> int {

    var libc = C()

    libc.printf("--- Recursive ---\n")
    var i: int32 = 0
    while true {
        if i >= 10 {
            break
        }
        libc.printf("fib(%d) = %d\n", i, fibRecursive(i))
        i = i + 1
    }

    libc.printf("--- Iterative ---\n")
    var j: int32 = 0
    while true {
        if j >= 10 {
            break
        }
        libc.printf("fib(%d) = %d\n", j, fibIterative(j))
        j = j + 1
    }

    return 0
}