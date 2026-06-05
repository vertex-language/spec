// atomic_amd64.vs
package atomic
build intrinsics

func load32(addr: *uint32) -> uint32 {
    return asm(
        "mov eax, [rdi]",
        "mfence",
        in("rdi") addr,
        out("eax")
    )
}

func store32(addr: *uint32, val: uint32) {
    asm(
        "mfence",
        "mov [rdi], esi",
        in("rdi") addr,
        in("esi") val
    )
}

// lock xadd reads esi (the increment) and writes esi (the old value of [rdi]).
// inout is self-contained: esi is seeded with val and its exit value is returned.
func add32(addr: *uint32, val: uint32) -> uint32 {
    return asm(
        "lock xadd [rdi], esi",
        in("rdi") addr,
        inout("esi") val
    )
}

// cmpxchg reads eax (expected) and conditionally writes [rdi]; eax is
// overwritten with the observed value on failure. in + clobber on the same
// register is valid here: the emitter converts it to a "+a" inout-with-discard.
func cas32(addr: *uint32, expected: uint32, desired: uint32) -> bool {
    return asm(
        "lock cmpxchg [rdi], ecx",
        in("rdi") addr,
        in("eax") expected,
        in("ecx") desired,
        out("zf"),
        clobber("eax")
    )
}

func load64(addr: *uint64) -> uint64 {
    return asm(
        "mov rax, [rdi]",
        "mfence",
        in("rdi") addr,
        out("rax")
    )
}

func store64(addr: *uint64, val: uint64) {
    asm(
        "mfence",
        "mov [rdi], rsi",
        in("rdi") addr,
        in("rsi") val
    )
}

func add64(addr: *uint64, val: uint64) -> uint64 {
    return asm(
        "lock xadd [rdi], rsi",
        in("rdi") addr,
        inout("rsi") val
    )
}

func cas64(addr: *uint64, expected: uint64, desired: uint64) -> bool {
    return asm(
        "lock cmpxchg [rdi], rcx",
        in("rdi") addr,
        in("rax") expected,
        in("rcx") desired,
        out("zf"),
        clobber("rax")
    )
}

func fence() {
    asm("mfence")
}