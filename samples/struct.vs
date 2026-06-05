package main

import "linux/libc"

class C : libc {
    func printf(fmt: string, ...) -> int32
    func exit(code: int32)
}

struct S {
    a: int32
    b: int32
    c: int32
}

func main() -> int {

    var s = S{a: 1, b: 2, c: 3}
    var c = C()
    c.printf("S: a=%d, b=%d, c=%d\n", s.a, s.b, s.c)
    
    return 0
}