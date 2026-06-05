// memory_amd64.vs
package memory
build intrinsics

func copy(dst: *uint8, src: *const uint8, len: uint64) {
    asm(
        "shr rcx, 3",
        "rep movsq",
        in("rdi") dst,
        in("rsi") src,
        in("rcx") len,
        clobber("flags")
    )
}

func move(dst: *uint8, src: *const uint8, len: uint64) {
    asm(
        "cmp rdi, rsi",
        "je 3f",
        "jb 1f",
        "lea rax, [rdi + rcx - 1]",
        "cmp rax, rsi",
        "jbe 1f",
        "std",
        "lea rdi, [rdi + rcx - 1]",
        "lea rsi, [rsi + rcx - 1]",
        "rep movsb",
        "cld",
        "jmp 3f",
        "1: rep movsb",
        "3:",
        in("rdi") dst,
        in("rsi") src,
        in("rcx") len,
        clobber("rax", "flags")
    )
}

func set(dst: *uint8, val: uint8, len: uint64) {
    asm(
        "rep stosb",
        in("rdi") dst,
        in("al") val,
        in("rcx") len,
        clobber("flags")
    )
}

func zero(dst: *uint8, len: uint64) {
    asm(
        "xor eax, eax",
        "rep stosb",
        in("rdi") dst,
        in("rcx") len,
        clobber("rax", "flags")
    )
}