# intrinsics — Machine Code Layer

## The Line

`intrinsics/*` is machine code. Nothing else.

No libc. No OS. No firmware. No linker. No runtime.
Every call lowers directly to CPU instructions at the ir/c level.
No `CALL` instruction is emitted. No symbol appears in the binary.

If it requires an OS to service it — it does not belong here.
If it requires firmware to be present — it does not belong here.
If it requires a linked library — it does not belong here.
If the CPU can execute it in an empty address space — it belongs here.

---

## Compiler Behavior

A package tagged `build intrinsics`:

- Is processed before all other packages, before the package graph is walked
- Every call site is inlined at the ir/c level — no `CALL`, no symbol
- Does not appear in the final binary in any form
- Every function body must consist entirely of a single `asm()` expression,
  or be a compiler-resolved hint (see §hint)

Import access is enforced by the compiler. Only packages tagged
`build builtin` or `build core` may import `intrinsics/*`.
Any other import is a hard compiler error.

---

## Inline Assembly

`asm()` is the only valid function body form inside a `build intrinsics`
package. It is a compile error anywhere else in the language.

### Syntax

Assembly blocks are parsed as variadic expressions. Instructions are provided
as comma-separated string literals, followed by register constraints.

```vertex
asm(
    "instruction",
    "instruction",
    in("register") param,
    inout("register") param,
    out("register"),
    clobber("register")
)
```

Functions that map physical output registers to a return type use `return asm(...)`.
Functions with no return type evaluate the `asm(...)` expression implicitly as a void statement.

### Operand Declarations

| Declaration | Meaning |
| --- | --- |
| `in("reg") param` | register is loaded with param before the asm executes |
| `inout("reg") param` | register is seeded with param on entry and read after exit; its exit value is an **implicit output** contributing to the return in declaration order — no separate `out("reg")` for the same register is needed or permitted |
| `out("reg")` | one register or flag token whose exit value contributes one element to the return in declaration order; register is undefined on entry |
| `clobber("reg", ...)` | register(s) are trashed — not inputs or outputs; accepts multiple names for convenience |

**Tuple return ordering.** All output-producing constraints — `inout` and `out` — contribute
to the return tuple in declaration order. For a function returning `(T, bool)`, the first
output-producing constraint yields `T` and the second yields `bool`. `in` and `clobber`
constraints do not contribute to the return regardless of position.

**`inout` vs `in` + `out` for the same register.** When a register serves as both input
and output at the same width, always use `inout` — it is self-contained and produces both
the `AsmInOut` and the implicit `AsmOut` entry in the backend `AsmBlock`. The `in("reg") +
out("reg")` pattern is reserved for the narrow case where the same physical register is used
at *different widths* across the boundary, for example `in("x0") addr` (64-bit pointer) with
`out("w0")` (32-bit result) on ARM64.

### Assembly Grammar

Instruction strings are passed verbatim to the backend assembler. To ensure consistency
and readability across the Vertex standard library, all inline assembly must adhere to
the modern, official syntax standard for its respective architecture.

| Architecture | Expected Grammar | Formatting Rules |
| --- | --- | --- |
| **`amd64`** | **Intel Syntax** | `dest, src` ordering. No `%` register prefixes or `$` immediate prefixes. Matches the official Intel SDM. |
| **`arm64`** | **Standard AArch64** | `dest, src1, src2` ordering. Uses official ARM register sizing (`x0`, `w0`) and standard addressing modes. |

### Special Register Tokens

The following string tokens are valid in `out` and `clobber` declarations:

| Token | Meaning |
| --- | --- |
| `"cf"` | carry flag |
| `"zf"` | zero flag |
| `"sf"` | sign flag |
| `"of"` | overflow flag |
| `"flags"` | all condition flags |

### Rules

* `asm()` is only valid inside a `build intrinsics` function body.
* All asm is implicitly non-eliminatable — the backend never optimises
  across an asm boundary and never removes an asm block as dead code.
* `out` constraints map to the function return type in declaration order,
  interleaved with `inout` constraints. For tuple returns, every output-producing
  constraint contributes exactly one element.
* `clobber` registers must not appear in `in`, `inout`, or `out`, with one
  exception: a register may appear in both `in` and `clobber` when the instruction
  both reads it as an input and unconditionally destroys it (e.g. `cmpxchg` consuming
  `eax`). The emitter converts this pattern to a GCC `"+modifier"` with discarded
  output to suppress the diagnostic.
* `inout` declares a register that is live both entering and exiting the block.
  The function parameter is consumed; the register's exit value is the implicit output.
  Writing a separate `out("reg")` for the same register is a compile error.
* Hex encoding of every instruction is the backend's responsibility.
  The Vertex source never contains raw bytes.
* A function body is either a single `asm()` expression or a compiler-resolved
  hint. No other statements may appear alongside `asm`.

### Backend Representation

The compiler lowers `asm()` through successive layers, each carrying only what its stage needs:

| Layer | Representation | Responsibility |
| --- | --- | --- |
| Parser / Resolver | Typed `AsmExpr` AST node | Parses grammar, validates constraints, resolves operand types |
| Lowerer | `b.EmitAsm` / `b.AsmValue` calls | Inlines the intrinsics call site; the call vanishes, the `AsmBlock` is placed inline |
| `ir/c` | `AsmStmt` / `AsmExpr` + `AsmBlock` | Non-eliminatable IR node; `EmitC()` renders `__asm__ __volatile__` for debug inspection |
| `ir/mir` | `OpAsm` + `PinnedReg` table | Register allocator reads pinned physical register constraints; instruction strings are opaque |
| Encoder | Machine bytes | Assembles instruction strings to target machine code |

---

## Namespace Rule

The arch appears in the path only when the **concept has no equivalent
on other architectures.**

```
intrinsics/memory        ✓   copy/zero exist on every arch — arch is codegen detail
intrinsics/amd64/memory  ✗   ARM64 also copies memory — arch doesn't belong
intrinsics/amd64/port    ✓   IN/OUT has no ARM64 equivalent — arch belongs here
```

Cross-arch packages split implementation by file using build tags.
Each arch gets its own `.vs` file inside the package directory.
The function signatures are identical across files — only the `asm` bodies differ.

---

## Cross-Arch Packages

---

### intrinsics/memory

```vertex
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
```

```vertex
// memory_arm64.vs
package memory
build intrinsics

func copy(dst: *uint8, src: *const uint8, len: uint64) {
    asm(
        "1: cbz x2, 2f",
        "ldp x3, x4, [x1], #16",
        "stp x3, x4, [x0], #16",
        "subs x2, x2, #16",
        "b.gt 1b",
        "2:",
        in("x0") dst,
        in("x1") src,
        in("x2") len,
        clobber("x3", "x4", "flags")
    )
}

func move(dst: *uint8, src: *const uint8, len: uint64) {
    asm(
        "cmp x0, x1",
        "beq 3f",
        "blo 1f",
        "add x0, x0, x2",
        "add x1, x1, x2",
        "2: cbz x2, 3f",
        "ldrb w3, [x1, #-1]!",
        "strb w3, [x0, #-1]!",
        "subs x2, x2, #1",
        "b.gt 2b",
        "b 3f",
        "1: ldrb w3, [x1], #1",
        "strb w3, [x0], #1",
        "subs x2, x2, #1",
        "b.gt 1b",
        "3:",
        in("x0") dst,
        in("x1") src,
        in("x2") len,
        clobber("x3", "x4", "flags")
    )
}

func set(dst: *uint8, val: uint8, len: uint64) {
    asm(
        "1: cbz x2, 2f",
        "strb w1, [x0], #1",
        "subs x2, x2, #1",
        "b.gt 1b",
        "2:",
        in("x0") dst,
        in("w1") val,
        in("x2") len,
        clobber("flags")
    )
}

func zero(dst: *uint8, len: uint64) {
    asm(
        "1: cbz x1, 2f",
        "strb wzr, [x0], #1",
        "subs x1, x1, #1",
        "b.gt 1b",
        "2:",
        in("x0") dst,
        in("x1") len,
        clobber("flags")
    )
}
```

---

### intrinsics/atomic

```vertex
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
```

```vertex
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
```

---

### intrinsics/bit

```vertex
// bit_amd64.vs
package bit
build intrinsics

func popcount32(val: uint32) -> uint32 {
    return asm(
        "popcnt eax, edi",
        in("edi") val,
        out("eax")
    )
}

func popcount64(val: uint64) -> uint64 {
    return asm(
        "popcnt rax, rdi",
        in("rdi") val,
        out("rax")
    )
}

func clz32(val: uint32) -> uint32 {
    return asm(
        "lzcnt eax, edi",
        in("edi") val,
        out("eax")
    )
}

func clz64(val: uint64) -> uint64 {
    return asm(
        "lzcnt rax, rdi",
        in("rdi") val,
        out("rax")
    )
}

func ctz32(val: uint32) -> uint32 {
    return asm(
        "tzcnt eax, edi",
        in("edi") val,
        out("eax")
    )
}

func ctz64(val: uint64) -> uint64 {
    return asm(
        "tzcnt rax, rdi",
        in("rdi") val,
        out("rax")
    )
}

// bswap reads and writes the same register — inout is self-contained.
func bswap32(val: uint32) -> uint32 {
    return asm(
        "bswap eax",
        inout("eax") val
    )
}

func bswap64(val: uint64) -> uint64 {
    return asm(
        "bswap rax",
        inout("rax") val
    )
}
```

```vertex
// bit_arm64.vs
package bit
build intrinsics

func popcount32(val: uint32) -> uint32 {
    return asm(
        "fmov s0, w0",
        "cnt v0.8b, v0.8b",
        "addv b0, v0.8b",
        "fmov w0, s0",
        in("w0") val,
        out("w0"),
        clobber("v0")
    )
}

func popcount64(val: uint64) -> uint64 {
    return asm(
        "fmov d0, x0",
        "cnt v0.8b, v0.8b",
        "addv b0, v0.8b",
        "fmov x0, d0",
        in("x0") val,
        out("x0"),
        clobber("v0")
    )
}

func clz32(val: uint32) -> uint32 {
    return asm(
        "clz w0, w0",
        inout("w0") val
    )
}

func clz64(val: uint64) -> uint64 {
    return asm(
        "clz x0, x0",
        inout("x0") val
    )
}

func ctz32(val: uint32) -> uint32 {
    return asm(
        "rbit w0, w0",
        "clz w0, w0",
        inout("w0") val
    )
}

func ctz64(val: uint64) -> uint64 {
    return asm(
        "rbit x0, x0",
        "clz x0, x0",
        inout("x0") val
    )
}

func bswap32(val: uint32) -> uint32 {
    return asm(
        "rev w0, w0",
        inout("w0") val
    )
}

func bswap64(val: uint64) -> uint64 {
    return asm(
        "rev x0, x0",
        inout("x0") val
    )
}
```

---

### intrinsics/math

```vertex
// math_amd64.vs
package math
build intrinsics

// sqrtss reads and writes xmm0 — inout is self-contained.
func sqrtf(val: float) -> float {
    return asm(
        "sqrtss xmm0, xmm0",
        inout("xmm0") val
    )
}

func sqrt(val: float64) -> float64 {
    return asm(
        "sqrtsd xmm0, xmm0",
        inout("xmm0") val
    )
}

// vfmadd213ss: xmm0 = xmm0 * xmm1 + xmm2. xmm0 is both first operand and result.
func fmaf(a: float, b: float, c: float) -> float {
    return asm(
        "vfmadd213ss xmm0, xmm1, xmm2",
        inout("xmm0") a,
        in("xmm1") b,
        in("xmm2") c
    )
}

func fma(a: float64, b: float64, c: float64) -> float64 {
    return asm(
        "vfmadd213sd xmm0, xmm1, xmm2",
        inout("xmm0") a,
        in("xmm1") b,
        in("xmm2") c
    )
}

// Absolute value via bitmask: reads and writes xmm0; xmm1 is scratch.
func absf(val: float) -> float {
    return asm(
        "pcmpeqd xmm1, xmm1",
        "psrld xmm1, 1",
        "andps xmm0, xmm1",
        inout("xmm0") val,
        clobber("xmm1")
    )
}

func abs(val: float64) -> float64 {
    return asm(
        "pcmpeqq xmm1, xmm1",
        "psrlq xmm1, 1",
        "andpd xmm0, xmm1",
        inout("xmm0") val,
        clobber("xmm1")
    )
}

// minss: result = min(xmm0, xmm1) stored in xmm0. xmm0 is both read and written.
func minf(a: float, b: float) -> float {
    return asm(
        "minss xmm0, xmm1",
        inout("xmm0") a,
        in("xmm1") b
    )
}

func maxf(a: float, b: float) -> float {
    return asm(
        "maxss xmm0, xmm1",
        inout("xmm0") a,
        in("xmm1") b
    )
}

func min(a: float64, b: float64) -> float64 {
    return asm(
        "minsd xmm0, xmm1",
        inout("xmm0") a,
        in("xmm1") b
    )
}

func max(a: float64, b: float64) -> float64 {
    return asm(
        "maxsd xmm0, xmm1",
        inout("xmm0") a,
        in("xmm1") b
    )
}
```

```vertex
// math_arm64.vs
package math
build intrinsics

func sqrtf(val: float) -> float {
    return asm(
        "fsqrt s0, s0",
        inout("s0") val
    )
}

func sqrt(val: float64) -> float64 {
    return asm(
        "fsqrt d0, d0",
        inout("d0") val
    )
}

// fmadd s0, s0, s1, s2: s0 = s0 * s1 + s2.
func fmaf(a: float, b: float, c: float) -> float {
    return asm(
        "fmadd s0, s0, s1, s2",
        inout("s0") a,
        in("s1") b,
        in("s2") c
    )
}

func fma(a: float64, b: float64, c: float64) -> float64 {
    return asm(
        "fmadd d0, d0, d1, d2",
        inout("d0") a,
        in("d1") b,
        in("d2") c
    )
}

func absf(val: float) -> float {
    return asm(
        "fabs s0, s0",
        inout("s0") val
    )
}

func abs(val: float64) -> float64 {
    return asm(
        "fabs d0, d0",
        inout("d0") val
    )
}

func minf(a: float, b: float) -> float {
    return asm(
        "fmin s0, s0, s1",
        inout("s0") a,
        in("s1") b
    )
}

func maxf(a: float, b: float) -> float {
    return asm(
        "fmax s0, s0, s1",
        inout("s0") a,
        in("s1") b
    )
}

func min(a: float64, b: float64) -> float64 {
    return asm(
        "fmin d0, d0, d1",
        inout("d0") a,
        in("d1") b
    )
}

func max(a: float64, b: float64) -> float64 {
    return asm(
        "fmax d0, d0, d1",
        inout("d0") a,
        in("d1") b
    )
}
```

---

### intrinsics/overflow

```vertex
// overflow_amd64.vs
package overflow
build intrinsics

// add sets eax = a + b and captures the carry flag as the overflow indicator.
// eax is seeded with a (inout) and its exit value is tuple element 0.
// cf is tuple element 1. Declaration order determines tuple position.
func add32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "add eax, ecx",
        inout("eax") a,
        in("ecx") b,
        out("cf")
    )
}

func sub32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "sub eax, ecx",
        inout("eax") a,
        in("ecx") b,
        out("cf")
    )
}

// imul eax, ecx is the 2-operand form: eax = eax * ecx (32-bit result).
// OF is set if the result does not fit in 32 bits.
func mul32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "imul eax, ecx",
        inout("eax") a,
        in("ecx") b,
        out("of")
    )
}

func add64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "add rax, rcx",
        inout("rax") a,
        in("rcx") b,
        out("cf")
    )
}

func sub64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "sub rax, rcx",
        inout("rax") a,
        in("rcx") b,
        out("cf")
    )
}

func mul64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "imul rax, rcx",
        inout("rax") a,
        in("rcx") b,
        out("of")
    )
}

// Saturating add: sbb ecx, ecx produces 0 (no carry) or 0xFFFFFFFF (carry),
// then or eax, ecx saturates to 0xFFFFFFFF. ecx is consumed as an input and
// then overwritten by sbb — list it in both in and clobber. The emitter
// converts in+clobber on the same register to a "+c" inout-with-discard.
func sadd32(a: uint32, b: uint32) -> uint32 {
    return asm(
        "add eax, ecx",
        "sbb ecx, ecx",
        "or eax, ecx",
        inout("eax") a,
        in("ecx") b,
        clobber("ecx", "flags")
    )
}

func ssub32(a: uint32, b: uint32) -> uint32 {
    return asm(
        "sub eax, ecx",
        "sbb ecx, ecx",
        "not ecx",
        "and eax, ecx",
        inout("eax") a,
        in("ecx") b,
        clobber("ecx", "flags")
    )
}

func sadd64(a: uint64, b: uint64) -> uint64 {
    return asm(
        "add rax, rcx",
        "sbb rcx, rcx",
        "or rax, rcx",
        inout("rax") a,
        in("rcx") b,
        clobber("rcx", "flags")
    )
}

func ssub64(a: uint64, b: uint64) -> uint64 {
    return asm(
        "sub rax, rcx",
        "sbb rcx, rcx",
        "not rcx",
        "and rax, rcx",
        inout("rax") a,
        in("rcx") b,
        clobber("rcx", "flags")
    )
}
```

```vertex
// overflow_arm64.vs
package overflow
build intrinsics

// adds sets flags; w0 holds the result. w0 is both input (a) and output (result).
func add32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "adds w0, w0, w1",
        inout("w0") a,
        in("w1") b,
        out("cf")
    )
}

func sub32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "subs w0, w0, w1",
        inout("w0") a,
        in("w1") b,
        out("cf")
    )
}

// smull x2, w0, w1: 64-bit product in x2. mov w0, w2 extracts the low 32 bits.
// asr + cmp checks whether the high 32 bits are a sign extension of the low 32.
func mul32(a: uint32, b: uint32) -> (uint32, bool) {
    return asm(
        "smull x2, w0, w1",
        "mov w0, w2",
        "asr x3, x2, #32",
        "cmp w3, w0, asr #31",
        inout("w0") a,
        in("w1") b,
        out("of"),
        clobber("w2", "w3")
    )
}

func add64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "adds x0, x0, x1",
        inout("x0") a,
        in("x1") b,
        out("cf")
    )
}

func sub64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "subs x0, x0, x1",
        inout("x0") a,
        in("x1") b,
        out("cf")
    )
}

// mul x0, x0, x1: low 64 bits of product in x0. smulh gives the high 64 bits.
// cmp checks whether the high bits are a sign extension of the low bits.
func mul64(a: uint64, b: uint64) -> (uint64, bool) {
    return asm(
        "mul x0, x0, x1",
        "smulh x2, x0, x1",
        "cmp x2, x0, asr #63",
        inout("x0") a,
        in("x1") b,
        out("of"),
        clobber("x2")
    )
}

// uqadd performs unsigned saturating add: w0 = sat(w0 + w1).
func sadd32(a: uint32, b: uint32) -> uint32 {
    return asm(
        "uqadd w0, w0, w1",
        inout("w0") a,
        in("w1") b
    )
}

func ssub32(a: uint32, b: uint32) -> uint32 {
    return asm(
        "uqsub w0, w0, w1",
        inout("w0") a,
        in("w1") b
    )
}

func sadd64(a: uint64, b: uint64) -> uint64 {
    return asm(
        "uqadd x0, x0, x1",
        inout("x0") a,
        in("x1") b
    )
}

func ssub64(a: uint64, b: uint64) -> uint64 {
    return asm(
        "uqsub x0, x0, x1",
        inout("x0") a,
        in("x1") b
    )
}
```

---

### intrinsics/hint

`likely` and `unlikely` are compiler-resolved. They carry no instruction —
the backend emits branch weight metadata. No `asm()` block is valid or
required for these two functions.

`prefetch_r` and `prefetch_w` require `locality` to be a compile-time
constant integer literal. The backend selects the correct prefetch variant
based on the constant value at the call site.

| locality | amd64 instruction | arm64 instruction |
| --- | --- | --- |
| `0` | `PREFETCHNTA` | `PRFM PLDL1KEEP` |
| `1` | `PREFETCHT2` | `PRFM PLDL2KEEP` |
| `2` | `PREFETCHT1` | `PRFM PLDL3KEEP` |
| `3` | `PREFETCHT0` | `PRFM PLDL1STRM` |

```vertex
// hint_amd64.vs
package hint
build intrinsics

func prefetch_r(ptr: *uint8, locality: uint8) {
    // locality dispatch is compile-time — backend selects variant
    asm(
        "prefetcht0 [rdi]",
        in("rdi") ptr
    )
}

func prefetch_w(ptr: *uint8, locality: uint8) {
    asm(
        "prefetchw [rdi]",
        in("rdi") ptr
    )
}

func pause() {
    asm("pause")
}

func unreachable() {
    asm("ud2")
}

// compiler-resolved — no asm block
func likely  (v: bool) -> bool
func unlikely(v: bool) -> bool
```

```vertex
// hint_arm64.vs
package hint
build intrinsics

func prefetch_r(ptr: *uint8, locality: uint8) {
    asm(
        "prfm pldl1keep, [x0]",
        in("x0") ptr
    )
}

func prefetch_w(ptr: *uint8, locality: uint8) {
    asm(
        "prfm pstl1keep, [x0]",
        in("x0") ptr
    )
}

func pause() {
    asm("yield")
}

func unreachable() {
    asm("udf #0")
}

// compiler-resolved — no asm block
func likely  (v: bool) -> bool
func unlikely(v: bool) -> bool
```

---

### intrinsics/cpu

```vertex
// cpu_amd64.vs
package cpu
build intrinsics

func halt() {
    asm("hlt")
}

func cli() {
    asm("cli")
}

func sti() {
    asm("sti")
}

func barrier() {
    asm("mfence")
}

func nop() {
    asm("nop")
}
```

```vertex
// cpu_arm64.vs
package cpu
build intrinsics

func halt() {
    asm("wfi")
}

func cli() {
    asm("msr daifset, #2")
}

func sti() {
    asm("msr daifclr, #2")
}

func barrier() {
    asm("dmb sy")
}

func nop() {
    asm("nop")
}
```

---

### intrinsics/mmio

All asm is implicitly non-eliminatable — this covers the volatile
semantics MMIO requires. No additional annotation is needed.
Pair with `cpu.barrier` when instruction ordering across MMIO
accesses matters.

```vertex
// mmio_amd64.vs
package mmio
build intrinsics

func read8(addr: uint64) -> uint8 {
    return asm(
        "mov al, [rdi]",
        in("rdi") addr,
        out("al")
    )
}

func read16(addr: uint64) -> uint16 {
    return asm(
        "mov ax, [rdi]",
        in("rdi") addr,
        out("ax")
    )
}

func read32(addr: uint64) -> uint32 {
    return asm(
        "mov eax, [rdi]",
        in("rdi") addr,
        out("eax")
    )
}

func read64(addr: uint64) -> uint64 {
    return asm(
        "mov rax, [rdi]",
        in("rdi") addr,
        out("rax")
    )
}

func write8(addr: uint64, val: uint8) {
    asm(
        "mov [rdi], al",
        in("rdi") addr,
        in("al") val
    )
}

func write16(addr: uint64, val: uint16) {
    asm(
        "mov [rdi], ax",
        in("rdi") addr,
        in("ax") val
    )
}

func write32(addr: uint64, val: uint32) {
    asm(
        "mov [rdi], esi",
        in("rdi") addr,
        in("esi") val
    )
}

func write64(addr: uint64, val: uint64) {
    asm(
        "mov [rdi], rsi",
        in("rdi") addr,
        in("rsi") val
    )
}
```

```vertex
// mmio_arm64.vs
package mmio
build intrinsics

func read8(addr: uint64) -> uint8 {
    return asm(
        "ldrb w0, [x0]",
        in("x0") addr,
        out("w0")
    )
}

func read16(addr: uint64) -> uint16 {
    return asm(
        "ldrh w0, [x0]",
        in("x0") addr,
        out("w0")
    )
}

func read32(addr: uint64) -> uint32 {
    return asm(
        "ldr w0, [x0]",
        in("x0") addr,
        out("w0")
    )
}

func read64(addr: uint64) -> uint64 {
    return asm(
        "ldr x0, [x0]",
        in("x0") addr,
        out("x0")
    )
}

func write8(addr: uint64, val: uint8) {
    asm(
        "strb w1, [x0]",
        in("x0") addr,
        in("w1") val
    )
}

func write16(addr: uint64, val: uint16) {
    asm(
        "strh w1, [x0]",
        in("x0") addr,
        in("w1") val
    )
}

func write32(addr: uint64, val: uint32) {
    asm(
        "str w1, [x0]",
        in("x0") addr,
        in("w1") val
    )
}

func write64(addr: uint64, val: uint64) {
    asm(
        "str x1, [x0]",
        in("x0") addr,
        in("x1") val
    )
}
```

---

## Arch-Exclusive Packages

---

### intrinsics/amd64/port

x86 has a separate port I/O address space accessed via dedicated
instructions. ARM64 has no equivalent — all hardware access on
ARM64 goes through MMIO.

```vertex
// port_x86.vs
package port
build intrinsics

func in8(port: uint16) -> uint8 {
    return asm(
        "in al, dx",
        in("dx") port,
        out("al")
    )
}

func in16(port: uint16) -> uint16 {
    return asm(
        "in ax, dx",
        in("dx") port,
        out("ax")
    )
}

func in32(port: uint16) -> uint32 {
    return asm(
        "in eax, dx",
        in("dx") port,
        out("eax")
    )
}

func out8(port: uint16, val: uint8) {
    asm(
        "out dx, al",
        in("dx") port,
        in("al") val
    )
}

func out16(port: uint16, val: uint16) {
    asm(
        "out dx, ax",
        in("dx") port,
        in("ax") val
    )
}

func out32(port: uint16, val: uint32) {
    asm(
        "out dx, eax",
        in("dx") port,
        in("eax") val
    )
}
```

---

### intrinsics/amd64/msr

```vertex
// msr_amd64.vs
package msr
build intrinsics

// rdmsr: reads MSR[ecx] into edx:eax. Shift and combine into rax for return.
func read(reg: uint32) -> uint64 {
    return asm(
        "rdmsr",
        "shl rdx, 32",
        "or rax, rdx",
        in("ecx") reg,
        out("rax"),
        clobber("rdx")
    )
}

// wrmsr: writes edx:eax to MSR[ecx]. Split val across rdx:rax before the write.
func write(reg: uint32, val: uint64) {
    asm(
        "mov rdx, rax",
        "shr rdx, 32",
        "wrmsr",
        in("ecx") reg,
        in("rax") val,
        clobber("rdx")
    )
}
```

---

### intrinsics/arm64/sysreg

ARM64 system register identifiers are encoded in the instruction at
compile time. `reg` must be a compile-time constant. Constants are
defined in `core/arm64/sysreg_const`.

```vertex
// sysreg_arm64.vs
package sysreg
build intrinsics

func read(reg: uint16) -> uint64 {
    // reg is a compile-time constant — backend encodes into MRS
    return asm(
        "mrs x0, <reg>",
        out("x0")
    )
}

func write(reg: uint16, val: uint64) {
    // reg is a compile-time constant — backend encodes into MSR
    asm(
        "msr <reg>, x0",
        in("x0") val
    )
}
```

---

### intrinsics/arm64/smc

Secure Monitor Call — transitions to EL3. No x86 equivalent.
x0 carries the call ID on entry and the return value on exit — inout is self-contained.

```vertex
// smc_arm64.vs
package smc
build intrinsics

func call(id: uint64, a1: uint64, a2: uint64, a3: uint64) -> uint64 {
    return asm(
        "smc #0",
        inout("x0") id,
        in("x1") a1,
        in("x2") a2,
        in("x3") a3
    )
}
```

---

## Full Map

```
intrinsics/
  memory/
    memory_amd64.vs     copy · move · set · zero
    memory_arm64.vs     copy · move · set · zero
  atomic/
    atomic_amd64.vs     load · store · add · cas · fence  (32 + 64)
    atomic_arm64.vs     load · store · add · cas · fence  (32 + 64)
  bit/
    bit_amd64.vs        popcount · clz · ctz · bswap      (32 + 64)
    bit_arm64.vs        popcount · clz · ctz · bswap      (32 + 64)
  math/
    math_amd64.vs       sqrtf/sqrt · fmaf/fma · absf/abs · minf/maxf/min/max
    math_arm64.vs       sqrtf/sqrt · fmaf/fma · absf/abs · minf/maxf/min/max
  overflow/
    overflow_amd64.vs   checked add/sub/mul · saturating add/sub  (32 + 64)
    overflow_arm64.vs   checked add/sub/mul · saturating add/sub  (32 + 64)
  hint/
    hint_amd64.vs       prefetch_r · prefetch_w · pause · unreachable
    hint_arm64.vs       prefetch_r · prefetch_w · pause · unreachable
                        likely · unlikely  (compiler-resolved, both arches)
  cpu/
    cpu_amd64.vs        halt · cli · sti · barrier · nop
    cpu_arm64.vs        halt · cli · sti · barrier · nop
  mmio/
    mmio_amd64.vs       read8/16/32/64 · write8/16/32/64
    mmio_arm64.vs       read8/16/32/64 · write8/16/32/64

  amd64/
    port.vs             in8/16/32 · out8/16/32
    msr.vs              read · write

  arm64/
    sysreg.vs           read · write
    smc.vs              call