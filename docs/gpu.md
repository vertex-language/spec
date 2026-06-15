# vertex_gpu.md

# GPU Functions in Vertex

## Reference for `gpu`-qualified Function Bodies

GPU functions in Vertex compile through `ir/gpu` to PTX (NVIDIA/CUDA), SPIR-V
(Vulkan), or MSL (Apple Metal) — whichever backend is present at runtime. This
document covers everything accessible inside a `gpu` function body and on its
declaration site.

---

## 1. Execution Model

A `gpu` function does not run once. It runs **once per thread**, across a grid
of thousands to millions of threads simultaneously. The function body is **what
one thread does**, parameterized by its position in the grid. Individual GPU
cores are slower than CPU cores; all speedup comes from parallelism and memory
bandwidth.

```vertex
// Each invocation is one thread. The bounds check replaces a loop.
func vecAdd(
    a:   readonly [float32],
    b:   readonly [float32],
    out: [float32],
    n:   uint32,
) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX       // this thread's linear index
    if i >= n { return }        // out-of-bounds threads exit silently
    out[i] = a[i] + b[i]       // one thread, one element
}

vecAdd(a: x, b: y, out: result, n: n).dispatch()
```

Consequences to keep in mind:

- **Divergence is expensive.** Threads in the same subgroup that take different
  branches serialize both paths — all threads execute both arms, inactive ones
  are masked. Branchy logic rarely benefits from GPU lowering.
- **Memory layout dominates.** Adjacent threads accessing adjacent elements
  (coalesced access) can be 10–50× faster than strided or random access.
  The compiler does not reorder your accesses.
- **Data-parallel maps over large buffers are the win condition.** If the body
  maps cleanly onto "one thread per element," it belongs here.

---

## 2. Function Declaration

### 2.1 Basic form

```vertex
func name(params) gpu                 { body }   // void, arrow omitted
func name(params) gpu -> void         { body }   // void, explicit
func name(params) gpu -> float32      { body }   // scalar return (§5)
func name(params) gpu -> [float32]    { body }   // slice return (§5)
```

`gpu` sits between the parameter list and the return arrow — identical in
position to `async`, `thread`, and `process`.

### 2.2 Workgroup size

Every `gpu` function requires a compile-time workgroup size. It is specified
inside the `gpu` qualifier. The size is fixed at compile time; SPIR-V requires
it, and the compiler specializes per size if you need multiple variants.

```vertex
// 1D — most common form
func vecAdd(...) gpu(workgroup: 256) -> void { }

// 3D — for 2D tile or volume kernels
func matKernel(...) gpu(workgroup: (16, 16, 1)) -> void { }
```

If `workgroup` is omitted, the compiler defaults to `(64, 1, 1)`. Specifying
it explicitly is strongly recommended for any kernel where occupancy matters.

### 2.3 Feature requirements

Portable features — capabilities that exist on all three backends but are
version- or hardware-gated — are declared with `require` inside the `gpu`
qualifier. `Lower` fails with a structured diagnostic if the chosen backend
cannot satisfy them, giving the host a clean fallback signal.

```vertex
func dotF16(a: [float16], b: [float16], n: uint32) gpu(workgroup: 256, require: .f16) -> void { }

func gemm(...) gpu(workgroup: 128, require: .matrix, .asyncCopy) -> void { }

func softmax(...) gpu(workgroup: 256, require: .subgroup) -> void { }
```

**Portable feature table:**

| Tag            | Capability                                     | Cannot lower on         |
|----------------|------------------------------------------------|-------------------------|
| `.f16`         | `float16` arithmetic                           | —                       |
| `.bf16`        | `bfloat16` arithmetic                          | Metal < 3.1             |
| `.f64`         | `float64` arithmetic                           | **Metal (always)**      |
| `.i64`         | `int64` / `uint64`                             | —                       |
| `.atomic64`    | 64-bit atomics                                 | Metal < 2.4             |
| `.atomicF32Add`| `float32` atomic add (gradient accumulation)   | Metal < 3.0             |
| `.subgroup`    | Subgroup reductions, ballots, shuffles         | —                       |
| `.matrix`      | 16×16×16 cooperative matrix multiply-accumulate| —                       |
| `.asyncCopy`   | Async global→workgroup memory copy             | PTX < sm_80             |

### 2.4 Dispatch

```vertex
// Basic dispatch — runtime picks the best available backend.
vecAdd(a: x, b: y, out: result, n: n).dispatch()

// Target a specific device or pre-allocate scratch memory.
gemm(a: a, b: b, out: c, m: m, k: k).dispatch(gpu: 0, mem: 65536)
```

`.dispatch()` launches the kernel and blocks until it completes, then returns
the kernel's return value (if any — see §5).

---

## 3. Types Inside `gpu` Functions

Only a restricted type set is valid inside a `gpu` function. The set is the
three-way intersection of PTX, SPIR-V, and MSL.

### 3.1 Scalar types

| Vertex type  | Notes                                          |
|--------------|------------------------------------------------|
| `bool`       | Predicate / condition — lowers to `.pred`      |
| `int32`      | Canonical signed integer (`int` alias valid)   |
| `uint32`     | Canonical unsigned integer (`uint` alias valid)|
| `int64`      | Requires `require: .i64`                       |
| `uint64`     | Requires `require: .i64`                       |
| `float16`    | GPU-only type. Requires `require: .f16`        |
| `bfloat16`   | GPU-only type. Requires `require: .bf16`       |
| `float32`    | Workhorse float — always available             |
| `float64`    | Requires `require: .f64`; **never on Metal**   |

`float16` and `bfloat16` are GPU-only scalar types. They are not valid outside
a `gpu` function body or its parameter list. Precision for math intrinsics is
fast-math grade — sufficient for activations, not for numerics requiring IEEE
guarantees.

### 3.2 Types that are compile errors inside `gpu` functions

| Invalid type or construct             | Reason                                   |
|---------------------------------------|------------------------------------------|
| Raw pointers (`*T`, `*const T`)       | No pointer arithmetic in kernels         |
| `string`                              | No heap, no null termination             |
| Classes                               | No heap allocation                       |
| Dynamic arrays (`var x: [T] = []`)    | No heap allocation (buffers use `[T]` parameter syntax — §4.1) |
| Maps                                  | No heap allocation                       |
| Channels                              | No inter-thread IPC primitives           |
| Tuples (except return types)          | No compound register values              |
| Optionals (except return types)       | No tagged structs at runtime             |

All memory inside a `gpu` function is reached through buffer parameters (§4.1)
or `workgroup` declarations (§4.3). There is no heap.

---

## 4. Parameters

### 4.1 Buffer parameters

A slice parameter (`[T]`) in a `gpu` function is a GPU buffer — a flat,
device-resident array indexed by element position. The compiler assigns it a
binding slot and lowers it to an SSBO (SPIR-V), `.param .u64` (PTX), or
`device T* [[buffer(n)]]` (MSL).

```vertex
func kernel(
    src: readonly  [float32],    // read-only buffer, slot 0
    idx: readonly  [uint32],     // read-only buffer, slot 1
    out:           [float32],    // read-write buffer, slot 2
    n:             uint32,       // scalar param (§4.2)
) gpu(workgroup: 256) -> void { }
```

Buffer lengths are not implicit — pass element counts as scalar parameters.
There is no `.length` property on a buffer parameter inside a `gpu` function.

**Buffer qualifiers** (only valid on `[T]` parameters in `gpu` functions):

| Qualifier  | Effect                                                                 |
|------------|------------------------------------------------------------------------|
| `readonly` | Write to this buffer is a compile error in the body. Lowers to `NonWritable` (SPIR-V), `const` pointer (MSL), `ld.global.nc`-eligible (PTX). |
| `coherent` | Required for buffers that receive writes from concurrent workgroups (e.g. global atomic counters). Lowers to `Coherent` (SPIR-V), `volatile` (MSL), scoped ld/st (PTX). |

```vertex
func histogram(
    data:   readonly [uint32],
    counts: coherent [uint32],
    n:      uint32,
) gpu(workgroup: 256) -> void { }
```

### 4.2 Scalar parameters

Any non-slice parameter — `uint32`, `float32`, `int64`, etc. — is a scalar
parameter. All scalar parameters are bundled into a single push-constant block
(SPIR-V), trailing `.param` scalars (PTX), or a `constant&` struct in the last
buffer slot (MSL). They are read-only inside the body.

```vertex
func scale(buf: [float32], factor: float32, n: uint32) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX
    if i >= n { return }
    buf[i] = buf[i] * factor     // factor is a scalar param — read-only
}
```

### 4.3 Workgroup memory

`workgroup` declares shared memory visible to all threads in the same workgroup.
It is written at the top of the function body and lowers to `.shared` (PTX),
a `Workgroup` storage-class variable (SPIR-V), or a `threadgroup` array (MSL).

```vertex
func scan(data: readonly [float32], out: [float32], n: uint32) gpu(workgroup: 256) -> void {
    workgroup tile:    [float32; 256]    // 256-element float32 shared array
    workgroup flags:   [uint32;   64]    // 64-element uint32 shared array

    let li = gpu.localIndex
    tile[li] = gpu.globalIDX < n ? data[gpu.globalIDX] : 0.0
    gpu.barrier()
    // ... cooperative reduction over tile ...
}
```

**Rules:**

- `workgroup` declarations must appear at the top of the function body, before
  any other statements.
- Element count must be a compile-time integer literal.
- Element type must be a valid GPU scalar type (§3.1). No `readonly` or
  `coherent` qualifiers on workgroup declarations.
- Total workgroup memory across all declarations in a function must fit the
  backend limit (~48 KB on most hardware). The validator reports overflows.
- `workgroup` is only valid inside a `gpu` function body.

---

## 5. Return Types

### 5.1 Void return

The standard form for kernels that write to explicit output buffer parameters.

```vertex
func vecAdd(a: readonly [float32], b: readonly [float32], out: [float32], n: uint32) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX
    if i >= n { return }
    out[i] = a[i] + b[i]
}
```

### 5.2 Per-thread scalar return — `gpu -> T`

A `gpu -> T` function implicitly allocates an output buffer sized to the
dispatch grid. Each thread contributes one element by calling `return value`.
A bare `return` exits the thread without writing; unwritten slots are
zero-initialized. The caller receives a heap-allocated `[T]` and is
responsible for `.delete()`.

```vertex
func activation(x: readonly [float32], n: uint32) gpu(workgroup: 256) -> float32 {
    let i = gpu.globalIDX
    if i >= n { return }              // exits thread, writes nothing to output
    return gpu.tanh(x[i])             // thread i writes tanh(x[i]) to output[i]
}

let out = activation(x: x, n: n).dispatch()   // [float32] — caller owns it
defer out.delete()
```

### 5.3 `gpu -> [T]`

`gpu -> [T]` is the canonical form at the call site when the return type needs
to be a named slice type. Semantics are identical to `gpu -> T` — one element
per thread, zero-initialized before the kernel runs.

```vertex
func vectorAdd(a: readonly [float32], b: readonly [float32], n: uint32) gpu(workgroup: 256) -> [float32] {
    let i = gpu.globalIDX
    if i >= n { return }
    return a[i] + b[i]
}

let result = vectorAdd(a: x, b: y, n: n).dispatch()
defer result.delete()
```

### 5.4 Return rules summary

| Situation                          | Valid                            |
|------------------------------------|----------------------------------|
| Exit current thread, write nothing | `return` (bare)                  |
| Write one element to output        | `return expr` (non-void kernel)  |
| `gpu -> void` function             | bare `return` only               |
| Fall off end of body               | equivalent to bare `return`      |

---

## 6. Built-in Thread Indices

Read-only values accessible anywhere inside a `gpu` function body. They are
properties of the executing thread, not function calls — no parentheses.

```vertex
gpu.globalIDX      // uint32 — linear 1D global thread index (canonical workhorse)
gpu.globalID       // { x: uint32, y: uint32, z: uint32 } — 3D global invocation id
gpu.localID        // { x: uint32, y: uint32, z: uint32 } — position within workgroup
gpu.localIndex     // uint32 — flattened local index within workgroup
gpu.workgroupID    // { x: uint32, y: uint32, z: uint32 } — workgroup grid position
```

```vertex
// 1D kernel — the common case
let i = gpu.globalIDX

// 2D kernel — e.g. one thread per matrix element
let row = gpu.globalID.y
let col = gpu.globalID.x

// Workgroup-relative index — for addressing workgroup memory
let li = gpu.localIndex
```

**Subgroup built-ins** (require `require: .subgroup`):

```vertex
gpu.subgroupLane    // uint32 — this thread's lane index within the subgroup
gpu.subgroupSize    // uint32 — subgroup width, runtime value; NOT a compile-time constant
```

`gpu.subgroupSize` is 32 on NVIDIA and Apple, but variable on Vulkan. Portable
code must treat it as a runtime value — never fold it as a constant.

---

## 7. Subscript Memory Access

Buffers and workgroup arrays are accessed via subscript. There are no pointer
dereferences inside a `gpu` function.

```vertex
// Buffer reads and writes
let v  = src[i]    // load element i
dst[i] = v         // store element i — compile error if dst is readonly

// Workgroup memory reads and writes
let s  = tile[li]
tile[li] = s
```

Out-of-bounds subscript is undefined behavior. Guard with a bounds check:

```vertex
if i >= n { return }
// safe to access buf[i] here
```

---

## 8. Operators

Standard Vertex operators work on all valid GPU scalar types.

**Arithmetic:**
```vertex
a + b    a - b    a * b    a / b    a % b    -a
a &+ b   a &- b   a &* b   // overflow variants
```

**Bitwise:**
```vertex
~a    a & b    a | b    a ^ b    a << b    a >> b
```

**Comparison:**
```vertex
a == b    a != b    a < b    a <= b    a > b    a >= b
```

**Logic:**
```vertex
!a    a && b    a || b
```

**Ternary:**
```vertex
condition ? a : b
```

Integer division truncates toward zero. Integer overflow wraps when using the
`&+`, `&-`, `&*` overflow operators.

---

## 9. Math Intrinsics

GPU math intrinsics live in the `gpu` namespace. They lower to SFU `.approx`
instructions (PTX), GLSL.std.450 (SPIR-V), and the `metal::` standard library
(MSL). Precision is fast-math grade — approximately correct, not IEEE-rounded.

```vertex
// General math
gpu.min(x, y)          // minimum of two values — same type
gpu.max(x, y)          // maximum of two values — same type
gpu.abs(x)             // absolute value
gpu.fma(x, y, z)       // fused multiply-add: x * y + z (one rounding step)
gpu.select(p, x, y)    // predicated select: p ? x : y  (no branch)

// Floating-point math (float32, float16, float64 where available)
gpu.sqrt(x)            // square root
gpu.rsqrt(x)           // reciprocal square root — fast, approximate
gpu.exp(x)             // eˣ
gpu.exp2(x)            // 2ˣ
gpu.log2(x)            // log₂(x)
gpu.sin(x)             // sine
gpu.cos(x)             // cosine
gpu.tanh(x)            // hyperbolic tangent — activation workhorse

// Integer bit ops
gpu.popcount(x)        // count set bits
gpu.clz(x)             // count leading zeros
gpu.reverseBits(x)     // bit reversal
```

### 9.1 Type conversion

Standard Vertex numeric conversion syntax applies inside `gpu` functions:

```vertex
let f  = float32(i)     // int32 → float32, always safe
let i  = uint32(3.7)    // float32 → uint32, truncates toward zero → 3
let h  = float16(f)     // float32 → float16 narrowing  (require: .f16)
let f2 = float32(h)     // float16 → float32 widening
let bf = bfloat16(f)    // float32 → bfloat16 narrowing (require: .bf16)
```

### 9.2 Bitcast

Bit-pattern reinterpretation — raw bits, no numeric conversion:

```vertex
let bits = gpu.bitcast<uint32>(f)    // float32 → uint32, same bit pattern
let f    = gpu.bitcast<float32>(u)   // uint32 → float32
let u16  = gpu.bitcast<uint16>(h)    // float16 → uint16
```

---

## 10. Control Flow

Control flow inside a `gpu` function is **structured only** — no `goto`, no
unstructured jumps. This is the SPIR-V structured control flow constraint,
promoted to a rule for all backends. Since `goto` does not exist in Vertex, no
new restriction is imposed beyond the standard language.

```vertex
// If / else
if cond {
    // ...
} else if other {
    // ...
} else {
    // ...
}

// While loop
var j: uint32 = 0
while j < k {
    j += 1
}

// For-in — half-open range
for t in 0..<kTiles {
    // t: uint32
}

// Early thread exit (most common use of bare return)
if i >= n { return }

// Break and continue work normally inside loops
for j in 0..<128 {
    if tile[j] == 0 { continue }
    if tile[j] > limit { break }
}
```

**Divergence warning.** A branch where some threads in a subgroup take `if`
and others take `else` serializes both paths. All threads execute both arms;
inactive threads are masked out. Minimize divergence in hot inner loops.

**Uniform control flow requirement.** Matrix operations (§13) and subgroup
operations (§12) must appear in *uniform* control flow — a path that all
threads in the subgroup reach together. The validator rejects these operations
inside a provably divergent branch.

---

## 11. Barriers

```vertex
gpu.barrier()           // workgroup barrier — synchronizes all threads in the
                        // workgroup and makes workgroup memory writes visible.
                        // Lowers to: bar.sync (PTX) · OpControlBarrier(WG, AcqRel)
                        // (SPIR-V) · threadgroup_barrier(mem_threadgroup) (MSL)

gpu.subgroupBarrier()   // subgroup barrier — synchronizes threads within the subgroup.
                        // Requires require: .subgroup
```

The standard two-phase workgroup memory pattern:

```vertex
// Phase 1: all threads write their element to shared memory
tile[li] = data[gi]

gpu.barrier()            // every thread must cross this line

// Phase 2: all threads may now safely read any element
let neighbor = tile[(li + 1) % 256]
```

The portable memory model is **relaxed atomics + acquire-release workgroup
barriers**. `gpu.barrier()` is a full acquire-release fence over workgroup
memory on all three backends.

---

## 12. Atomics

Atomic operations are methods on buffer parameters and workgroup arrays. All
atomics use `relaxed` ordering (the only ordering MSL allows for
read-modify-write). Each returns the value **before** the operation.

```vertex
// Buffer atomics — target is buf[i]
let prev = buf.atomicAdd(i, v)
let prev = buf.atomicSub(i, v)
let prev = buf.atomicMin(i, v)
let prev = buf.atomicMax(i, v)
let prev = buf.atomicAnd(i, v)
let prev = buf.atomicOr(i, v)
let prev = buf.atomicXor(i, v)
let prev = buf.atomicExchange(i, v)
let prev = buf.atomicCas(i, cmp, val)   // swap if buf[i] == cmp; returns prior value

// Workgroup memory atomics — same interface, target is tile[j]
let prev = tile.atomicAdd(j, v)
let prev = tile.atomicCas(j, cmp, val)
```

**Extra requirements:**

| Operation                              | Requires             |
|----------------------------------------|----------------------|
| Atomics on `uint64` / `int64` elements | `require: .atomic64` |
| `buf.atomicAdd` on `float32` elements  | `require: .atomicF32Add` |

`atomicF32Add` is the workhorse for gradient accumulation — many threads
adding partial gradients to the same parameter element.

```vertex
// Example — global histogram
func histogram(
    data:   readonly [uint32],
    counts: coherent [uint32],    // coherent required: written by concurrent workgroups
    n:      uint32,
) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX
    if i >= n { return }
    counts.atomicAdd(data[i], 1)
}

// Example — gradient accumulation
func accumGrad(
    partial: readonly [float32],
    grad:    coherent [float32],
    n:       uint32,
) gpu(workgroup: 256, require: .atomicF32Add) -> void {
    let i = gpu.globalIDX
    if i >= n { return }
    grad.atomicAdd(i, partial[i])
}
```

---

## 13. Subgroup Operations  (`require: .subgroup`)

Subgroup operations cooperate across the threads within one subgroup (warp on
NVIDIA, SIMD lane group on Apple). They are faster than workgroup-memory
reductions and are the preferred building block for softmax, layernorm, and
loss computations.

```vertex
// Reductions — every active lane receives the same result
gpu.subgroupSum(x)              // sum across active lanes
gpu.subgroupMin(x)              // minimum
gpu.subgroupMax(x)              // maximum

// Scans — each lane receives a prefix value
gpu.subgroupInclusiveSum(x)     // prefix sum, this lane included
gpu.subgroupExclusiveSum(x)     // prefix sum, this lane excluded

// Predicates — return bool
gpu.subgroupAll(pred)           // true if pred is true for all active lanes
gpu.subgroupAny(pred)           // true if pred is true for any active lane
gpu.subgroupElect()             // true for exactly one lane (lowest active)

// Ballot — returns [uint32; 4] bitmask (SPIR-V uvec4 shape)
// Bits beyond gpu.subgroupSize are zero.
gpu.subgroupBallot(pred)

// Broadcasts and shuffles
gpu.subgroupBroadcastFirst(x)   // value from lowest active lane, broadcast to all
gpu.subgroupShuffleXor(x, mask) // exchange values between lanes XOR'd by mask
```

Subgroup operations must appear in uniform control flow (§10). The validator
rejects them inside a branch that is not provably reached by all threads in
the subgroup together.

---

## 14. Matrix Tiles  (`require: .matrix`)

Cooperative subgroup-scope matrix multiply-accumulate — the portable face of
tensor cores. Lowers to PTX `wmma`/`mma.sync`, `SPV_KHR_cooperative_matrix`
(SPIR-V), and `simdgroup_matrix` (MSL). Every lane in the subgroup participates
in each operation, exactly as in CUDA wmma.

The v1 portable shape is the universal intersection: **16×16×16, F16 inputs,
F32 accumulator** (BF16 inputs with `require: .bf16`). Wider shapes and fp8
are vendor territory (§16).

### 14.1 Tile kind constants

| Constant         | Shape / element type                              |
|------------------|---------------------------------------------------|
| `.acc16x16f32`   | 16×16 accumulator, `float32`                      |
| `.a16x16f16`     | 16×16 A-matrix input, `float16`                   |
| `.b16x16f16`     | 16×16 B-matrix input, `float16`                   |
| `.a16x16bf16`    | 16×16 A-matrix input, `bfloat16` (`.bf16`)        |
| `.b16x16bf16`    | 16×16 B-matrix input, `bfloat16` (`.bf16`)        |

### 14.2 Operations

```vertex
// Zero an accumulator
var acc = gpu.matZero(.acc16x16f32)

// Load a tile from a buffer
// buf     — buffer parameter
// rowOff  — element offset of this tile's top-left corner
// ld      — leading dimension (row stride) in elements
let ta = gpu.matLoad(.a16x16f16, aBuf, rowOff, lda)
let tb = gpu.matLoad(.b16x16f16, bBuf, colOff, ldb)

// Fused multiply-accumulate:  acc += ta × tb
acc = gpu.matMulAcc(ta, tb, acc)

// Store accumulator back to a buffer
gpu.matStore(cBuf, cOff, ldc, acc)
```

### 14.3 GEMM skeleton

```vertex
func gemm(
    a:   readonly [float16],
    b:   readonly [float16],
    c:   [float32],
    m:   uint32,
    n:   uint32,
    k:   uint32,
    lda: uint32,
    ldb: uint32,
    ldc: uint32,
) gpu(workgroup: 128, require: .matrix) -> void {
    let row = gpu.workgroupID.y * 16
    let col = gpu.workgroupID.x * 16

    var acc    = gpu.matZero(.acc16x16f32)
    let kTiles = k / 16

    for kt in 0..<kTiles {
        let aOff = row * lda + kt * 16
        let bOff = kt  * 16  * ldb + col
        let ta   = gpu.matLoad(.a16x16f16, a, aOff, lda)
        let tb   = gpu.matLoad(.b16x16f16, b, bOff, ldb)
        acc      = gpu.matMulAcc(ta, tb, acc)
    }

    gpu.matStore(c, row * ldc + col, ldc, acc)
}
```

---

## 15. Async Copy  (`require: .asyncCopy`)

Overlaps global-to-workgroup memory copies with compute — the standard
double-buffering pattern for GEMM and attention kernels. Lowers to `cp.async`
(PTX, sm_80+), the Vulkan workgroup-memory async path, and Metal's simdgroup
async copy family.

```vertex
// Enqueue a copy of `count` elements from buf[srcOff…] into tile[dstOff…]
gpu.asyncCopy(tile, dstOff, buf, srcOff, count)

// Commit the current in-flight copy group
gpu.asyncCommit()

// Block until at most n copy groups are still in flight (0 = wait for all)
gpu.asyncWait(n)

// Fence before reading the just-arrived data
gpu.barrier()
```

**Double-buffering skeleton:**

```vertex
func tiledGemm(...) gpu(workgroup: 128, require: .matrix, .asyncCopy) -> void {
    workgroup tileA: [float16; 256]
    workgroup tileB: [float16; 256]

    // Prefetch tile 0 before the loop
    gpu.asyncCopy(tileA, 0, a, aOff(0), 256)
    gpu.asyncCopy(tileB, 0, b, bOff(0), 256)
    gpu.asyncCommit()

    var acc = gpu.matZero(.acc16x16f32)

    for kt in 0..<kTiles {
        // Prefetch next tile while computing current one
        if kt + 1 < kTiles {
            gpu.asyncCopy(tileA, 0, a, aOff(kt + 1), 256)
            gpu.asyncCopy(tileB, 0, b, bOff(kt + 1), 256)
            gpu.asyncCommit()
        }

        gpu.asyncWait(1)      // allow ≤1 group in flight (current prefetch)
        gpu.barrier()

        let ta = gpu.matLoad(.a16x16f16, tileA, 0, 16)
        let tb = gpu.matLoad(.b16x16f16, tileB, 0, 16)
        acc    = gpu.matMulAcc(ta, tb, acc)
    }

    gpu.matStore(c, row * ldc + col, ldc, acc)
}
```

If the chosen backend does not support async copy, `Lower` fails the feature
check. Provide a synchronous fallback variant (§16.2) for those devices.

---

## 16. Vendor Extensions

When the portable tier is insufficient, vendor extensions unlock
hardware-specific instructions. They are always behind an explicit namespace
— `gpu.cuda.*`, `gpu.metal.*`, `gpu.vulkan.*` — so portability loss is
visible at the call site.

A function that uses a vendor extension can only lower on that backend. Lowering
against any other backend reports a structured `"vendor"` diagnostic for that
function and skips it — it never silently runs a slower emulated path.

### 16.1 Qualifier forms

```vertex
// Portable — lowers everywhere the listed features are available
func gemm(...)     gpu(workgroup: 128, require: .matrix, .asyncCopy) -> void { }

// CUDA-only — lowers only on PTX
func gemm__cuda(...)    gpu.cuda(workgroup: 128, require: .wgmma, .tma) -> void { }

// Metal-only — lowers only on MSL
func gemm__metal(...)   gpu.metal(workgroup: 256, require: .simdMatrixF16) -> void { }

// Vulkan-only — lowers only on SPIR-V
func gemm__vulkan(...)  gpu.vulkan(workgroup: 128, require: .coopMat2) -> void { }
```

### 16.2 CUDA intrinsics (`gpu.cuda.*`)

```vertex
// Tensor Memory Accelerator bulk async copy (Hopper+)
gpu.cuda.tmaLoad(tile, descriptor, coords)

// Warpgroup MMA (Hopper+)
gpu.cuda.wgmma(acc, tileA, tileB)

// Verbatim PTX splice — opaque to the optimizer, use as last resort
gpu.cuda.raw("wgmma.mma_async.sync.aligned.m64n128k16.f32.f16.f16 …")
```

| CUDA require tag  | Capability                                                   |
|-------------------|--------------------------------------------------------------|
| `.wgmma`          | Hopper/Blackwell warpgroup MMA (`wgmma` / `tcgen05`)         |
| `.tma`            | Tensor Memory Accelerator bulk async tensor copies           |
| `.clusterLaunch`  | Thread-block clusters, distributed shared memory             |

### 16.3 Metal intrinsics (`gpu.metal.*`)

```vertex
gpu.metal.simdMatMul(acc, ta, tb)
gpu.metal.raw("/* verbatim MSL source splice */")
```

| Metal require tag    | Capability                                       |
|----------------------|--------------------------------------------------|
| `.simdMatrixF16`     | Apple-specific simdgroup matrix shapes and types |
| `.imageblocks`       | Tile memory via Metal imageblocks                |

### 16.4 Vulkan intrinsics (`gpu.vulkan.*`)

```vertex
gpu.vulkan.raw("/* verbatim SPIR-V instruction splice */")
```

| Vulkan require tag | Capability                                        |
|--------------------|---------------------------------------------------|
| `.coopMat2`        | `SPV_NV_cooperative_matrix2` extended tile shapes |

The `*.raw(...)` splice is opaque to the optimizer, the validator, and any
future pass. Use only when no higher-level intrinsic covers the instruction.

---

## 17. Kernel Variants

The intended pattern for performance-critical kernels: a portable base function
and one or more vendor-specific variants sharing the same name. The runtime
automatically picks the best variant the device supports.

**Naming convention:** `funcName__cuda`, `funcName__metal`, `funcName__vulkan`.
The compiler recognizes these suffixes as variants of `funcName` and exposes
them through a single `.dispatch()` call site.

```vertex
// Portable — runs everywhere .matrix and .asyncCopy are supported
func gemm(
    a: readonly [float16], b: readonly [float16], c: [float32],
    m: uint32, n: uint32, k: uint32,
) gpu(workgroup: 128, require: .matrix, .asyncCopy) -> void {
    // 16×16×16 MatMulAcc pipeline (§14, §15)
}

// CUDA-only — Hopper warpgroup MMA + TMA (2–5× over portable on H100)
func gemm__cuda(
    a: readonly [float16], b: readonly [float16], c: [float32],
    m: uint32, n: uint32, k: uint32,
) gpu.cuda(workgroup: 128, require: .wgmma, .tma) -> void {
    gpu.cuda.tmaLoad(tileA, aDesc, coords)
    gpu.cuda.wgmma(acc, tileA, tileB)
}

// Metal-only — Apple simdgroup matrix shapes
func gemm__metal(
    a: readonly [float16], b: readonly [float16], c: [float32],
    m: uint32, n: uint32, k: uint32,
) gpu.metal(workgroup: 256, require: .simdMatrixF16) -> void {
    gpu.metal.simdMatMul(acc, ta, tb)
}
```

```vertex
// Runtime dispatch — picks gemm__cuda on Hopper, gemm__metal on Apple,
// gemm (portable) elsewhere, and fails at compile time if no variant covers
// the target device.
gemm(a: a, b: b, c: c, m: m, n: n, k: k).dispatch()
```

**Rules:**

- Variant functions must have identical parameter lists and return types.
- The base function (no suffix) must be a portable `gpu` or `gpu(...)` function.
  A module with only vendor variants and no portable base is a compile error.
- Each variant is validated against its own backend only. A vendor variant that
  fails its feature check on its own backend is reported at build time.
- `.dispatch()` on a device that has no matching variant falls back to the
  portable base. If the portable base also cannot lower (e.g. `.f64` on Metal),
  it reports the structured feature diagnostic — never silent degradation.
- The prefix is the warning label. Portable code is unmarked. Vendor code is
  loudly marked. The runtime — not the kernel author — decides which variant
  a given machine receives.

---

## 18. Validation

`ValidateModule` runs automatically at `.dispatch()` time (during lowering).
Invoke it explicitly for structured diagnostics in build tooling or test mode.

```vertex
// Structured issue reported per validation failure
{
    kernel: string,   // enclosing function name, or "" for module-level issues
    kind:   string,   // "feature" | "vendor" | "binding" | "structure" | "body"
    msg:    string,   // human-readable description
}
```

**Checks performed:**

- Every `require:` tag was declared, and the chosen backend supports it.
  `require: .f64` on Metal is the canonical hard failure.
- Vendor-extension functions only validate against their own backend. Lowering
  against other backends skips them and reports `kind: "vendor"` per function.
- No duplicate buffer parameter names, function names, or symbol names.
- Every code path terminates — `return` or falls off the end of the body.
- `workgroup:` size is positive, within backend limits, and (for `.matrix`
  kernels) is a multiple of `gpu.subgroupSize`.
- Total workgroup memory per function fits the backend limit.
- `break` and `continue` appear only inside loops.
- Matrix and subgroup operations appear only in uniform control flow.
- `readonly` buffer parameters are never written to.
- `workgroup` declarations appear only at the top of the function body.
- `gpu.subgroupLane`, `gpu.subgroupSize`, all `gpu.subgroup*` operations, all
  `gpu.mat*` operations, and `gpu.asyncCopy` appear only inside `gpu` function
  bodies.

---

## 19. Full Examples

### 19.1 Element-wise GELU activation

```vertex
func gelu(x: readonly [float32], out: [float32], n: uint32) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX
    if i >= n { return }

    let xi    = x[i]
    let x3    = xi * xi * xi
    let inner = 0.7978845 * (xi + 0.044715 * x3)
    out[i]    = xi * 0.5 * (1.0 + gpu.tanh(inner))
}
```

### 19.2 RMSNorm — subgroup reduction

```vertex
func rmsnorm(
    x:   readonly [float32],
    w:   readonly [float32],
    out: [float32],
    n:   uint32,
    eps: float32,
) gpu(workgroup: 256, require: .subgroup) -> void {
    let i  = gpu.globalIDX
    if i >= n { return }

    let xi  = x[i]
    let ssq = gpu.subgroupSum(xi * xi)
    let rms = gpu.rsqrt(ssq / float32(gpu.subgroupSize) + eps)
    out[i]  = xi * rms * w[i]
}
```

### 19.3 Adam optimizer step

```vertex
func adam(
    param: [float32],
    grad:  readonly [float32],
    m:     [float32],
    v:     [float32],
    lr:    float32,
    b1:    float32,
    b2:    float32,
    eps:   float32,
    n:     uint32,
) gpu(workgroup: 256) -> void {
    let i = gpu.globalIDX
    if i >= n { return }

    let g  = grad[i]
    let mi = b1 * m[i] + (1.0 - b1) * g
    let vi = b2 * v[i] + (1.0 - b2) * g * g
    m[i]      = mi
    v[i]      = vi
    param[i] -= lr * mi / (gpu.sqrt(vi) + eps)
}
```

### 19.4 Parallel prefix sum — workgroup scan

```vertex
func prefixSum(data: readonly [float32], out: [float32], n: uint32) gpu(workgroup: 256) -> void {
    workgroup tile: [float32; 256]

    let gi = gpu.globalIDX
    let li = gpu.localIndex

    tile[li] = gi < n ? data[gi] : 0.0
    gpu.barrier()

    var stride: uint32 = 1
    while stride < 256 {
        if li >= stride {
            tile[li] = tile[li] + tile[li - stride]
        }
        gpu.barrier()
        stride = stride * 2
    }

    if gi < n {
        out[gi] = tile[li]
    }
}
```

### 19.5 Inline anonymous GPU dispatch

From §35.1 of the grammar — the anonymous function form works with `gpu` too:

```vertex
let output = func(a: [float32], b: [float32], n: uint32) gpu(workgroup: 256) -> [float32] {
    let i = gpu.globalIDX
    if i >= n { return }
    return a[i] + b[i]
}(x, y, n).dispatch()

defer output.delete()
```

---

## 20. What Lowers Well vs. What to Offload

| Pattern                                    | Recommended approach                                     |
|--------------------------------------------|----------------------------------------------------------|
| Elementwise ops and activations            | Portable core — bare `gpu(workgroup: n)`                 |
| Bias / residual add, quant / dequant       | Portable core                                            |
| Softmax, layernorm, RMSNorm                | `require: .subgroup` (workgroup-memory fallback if needed) |
| Embedding lookup, gather / scatter         | Portable core                                            |
| Optimizer steps (Adam, SGD, LAMB)          | Portable core — purely elementwise                       |
| Gradient accumulation                      | `require: .atomicF32Add`                                 |
| Matmul, attention (majority of FLOPs)      | `require: .matrix, .asyncCopy`, or call cuBLAS / MPS from host and use `ir/gpu` for surrounding fused elementwise / norm code |
| BF16 training arithmetic                   | `require: .bf16`                                         |
| Hopper-class GEMM                          | `func gemm__cuda` with `gpu.cuda(.wgmma, .tma)`          |
| Branchy sequential logic                   | Do not lower to `gpu` — divergence serializes both paths |
| Dynamic memory allocation                  | Not possible inside `gpu` functions                      |
| Multi-device collectives, autograd         | Out of scope for `gpu` functions — lives in the runtime above `ir/gpu` |