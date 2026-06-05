package main
build linux

import "linux/lib/c"

class C : c {

    func printf(fmt:  ...*const char) -> int
}

func main() -> int {

    var libc = C()
    let m = 100

    if m == 100 {
        let x = "yes it's 100"
        libc.printf("%s\n", x)
    }
    
    return 0
}
