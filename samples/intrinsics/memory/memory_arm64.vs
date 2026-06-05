// atomic_arm64.vs
package atomic
build intrinsics

func load32(addr: *uint32) -> uint32 {
    return asm(
        "ldar w0, [x0]",
        in("x0") addr,
        out("w0")
    )
}

func store32(addr: *uint32, val: uint32) {
    asm(
        "stlr w1, [x0]",
        in("x0") addr,
        in("w1") val
    )
}

// ldaddal writes the old [x0] value into w0 and adds w1 to [x0].
// x0 (64-bit address) and w0 (32-bit result) are the same physical register
// at different widths — in + out at different widths is correct here.
func add32(addr: *uint32, val: uint32) -> uint32 {
    return asm(
        "ldaddal w1, w0, [x0]",
        in("x0") addr,
        in("w1") val,
        out("w0")
    )
}

func cas32(addr: *uint32, expected: uint32, desired: uint32) -> bool {
    return asm(
        "1: ldaxr w3, [x0]",
        "cmp w3, w1",
        "b.ne 2f",
        "stlxr w3, w2, [x0]",
        "cbnz w3, 1b",
        "mov w0, #1",
        "b 3f",
        "2: mov w0, #0",
        "3:",
        in("x0") addr,
        in("w1") expected,
        in("w2") desired,
        out("w0"),
        clobber("w3", "flags")
    )
}

func load64(addr: *uint64) -> uint64 {
    return asm(
        "ldar x0, [x0]",
        in("x0") addr,
        out("x0")
    )
}

func store64(addr: *uint64, val: uint64) {
    asm(
        "stlr x1, [x0]",
        in("x0") addr,
        in("x1") val
    )
}

// ldaddal: x0 is the address on entry and holds the old [x0] value on exit.
// Same physical register, same width — inout is correct.
func add64(addr: *uint64, val: uint64) -> uint64 {
    return asm(
        "ldaddal x1, x0, [x0]",
        inout("x0") addr,
        in("x1") val
    )
}

func cas64(addr: *uint64, expected: uint64, desired: uint64) -> bool {
    return asm(
        "1: ldaxr x3, [x0]",
        "cmp x3, x1",
        "b.ne 2f",
        "stlxr w3, x2, [x0]",
        "cbnz w3, 1b",
        "mov w0, #1",
        "b 3f",
        "2: mov w0, #0",
        "3:",
        in("x0") addr,
        in("x1") expected,
        in("x2") desired,
        out("w0"),
        clobber("x3", "flags")
    )
}

func fence() {
    asm("dmb ish")
}