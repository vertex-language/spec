# Vertex Language Grammar

## Specification 2.2 — Hardware Acceleration

---

## 0. Overview

`gpu` and `npu` are Vertex's device-offload markers, built into the core language. Each tells the compiler that a function's body does not run on the calling thread, but compiles instead to a separate target — PTX, AMDTX (custom), or MSL IR for `gpu`; StableHLO for `npu`.

The two markers differ by **programming model**, not by vendor:

| | `gpu` | `npu` |
| --- | --- | --- |
| Model | SIMT — per-thread execution over an index space | Whole-array — operations apply to entire tensors |
| Launch shape | `(blocks:, threads:)`, optional | none — shape is carried by the types |
| Body language | unrestricted Vertex | restricted (§2.4–§2.8) |
| Element access | ordinary subscripting | none; elementwise ops and `npu.` calls only |
| Divergent branching | permitted | rejected — selector must be scalar |

### 0.1 Naming

`npu` names a hardware class, as `gpu` does. It covers Google TPU, AWS Trainium, the Apple Neural Engine, Qualcomm Hexagon, Intel and AMD NPUs, and comparable array accelerators. No vendor name appears in Vertex source; the specific device is selected by the toolchain (§4).

An earlier draft of this document spelled the marker `tpu`. That name broke symmetry with `gpu` by sitting at the vendor level rather than the class level, and forced source targeting one vendor's silicon to be written using another's product name. The keyword `tpu` is removed from the language.

`tensor` remains the type constructor (§2.4) and is unaffected.

---

## 1. GPU

### 1.1 The `gpu` Marker (Signatures)

Functions intended to run on-device must be marked `gpu` in their signature:

```vertex
func matrixMult(x: []float32, y: []float32) gpu -> []float32 {
    // ordinary Vertex — no restricted types or constructs
}
```

Marking a function `gpu` tells the compiler to compile its body to one of PTX, AMDTX (custom), or MSL IR rather than host machine code. The function body itself is unrestricted Vertex — the same language you would write for a host function.

### 1.2 Invocation (Call-site Dispatch)

Calling a `gpu`-marked function dispatches it to the device and returns the result normally, as an ordinary function call. An optional `(blocks: n, threads: n)` config attaches at the call site:

```vertex
let d = gpu(blocks: 16, threads: 256) matrixMult(x, y)
```

Omitting the config dispatches with a compiler/runtime-chosen default launch shape:

```vertex
let d = gpu matrixMult(x, y)
```

Both forms are legal only when the callee is itself declared `gpu` (§1.1) — the marker must agree at both ends.

### 1.3 Return Values

A `gpu` call takes host-typed arguments and returns a plain host-typed result, just like a normal function call — the caller gets the value back directly, with no special handling needed.

---

## 2. NPU

### 2.1 The `npu` Marker (Signatures)

Functions intended to run on the array-accelerator backend (StableHLO) must be marked `npu` in their signature, mirroring `gpu` (§1.1):

```vertex
func vecAdd(a: tensor[float32, 1024], b: tensor[float32, 1024]) npu -> tensor[float32, 1024] {
    return a + b
}
```

An `npu`-marked body sets the `Npu` context parameter, which licenses `tensor` types and the `npu.` namespace (Annex A.0.2). Neither is available anywhere else.

### 2.2 Invocation (Call-site Dispatch)

Calling an `npu`-marked function passes a host array in as the `tensor`-typed argument, and returns a plain host array back — an ordinary, synchronous call:

```vertex
var ha: [1024]float32
var hb: [1024]float32

let sum = npu vecAdd(ha, hb)   // sum: [1024]float32
```

This is legal only when the callee is itself declared `npu` (§2.1) — the marker must agree at both ends, same as `gpu` (§1.2).

`npu` immediately followed by `.` is the builtin namespace (§2.7), never a launch prefix. The grammar enforces this with `[lookahead ≠ .]` on the launch production (Annex A.4.2), matching the treatment of `async` and `gpu`.

### 2.3 Return Values

Same rule as `gpu` (§1.3) — an `npu` call takes host-typed arguments and returns a plain host-typed result directly.

### 2.4 `tensor[ElementType, Shape...]`

* Valid only inside an `npu`-marked function body.
* **Signature-eligible:** `float32`, `int8`. **Body-only:** `bf16`, `fp8e4m3`, `fp8e5m2`, `int4`.
* **Shape:** one or more compile-time integer literals, following `ElementType` in the same bracketed, comma-separated list — `tensor[float32, 1024]` (1-D), `tensor[float32, 16, 16]` (2-D), and so on.
* No subscripting (`a[i]` is a compile error) — element access only via elementwise ops and `npu.` calls.

### 2.5 Elementwise Operators

`+ - * /` and unary `-`; comparisons `== != < <= > >=` yield `tensor[bool, Shape...]`. Operands must share element type and shape.

### 2.6 Casting & Quantization

* Plain casts (e.g. `bf16(val)`) saturate on overflow into `int8`/`int4`.
* `npu.Quantize[T](a, scale)` / `npu.Dequantize[T](a, scale)` — scalar-scaled conversion between `float32` and `int8`/`fp8`/`int4`.

### 2.7 `npu.` Builtin Namespace (reference)

| Category | Members |
|---|---|
| Math | `Abs Sign Floor Ceil Round Sqrt Rsqrt Exp Expm1 Log Log1p Sin Cos Tan Tanh Sigmoid IsFinite Max Min Mod Pow Atan2` |
| Contraction | `Dot(a, b)` — accumulates in `float32` regardless of input precision |
| Selection | `Select(cond, onTrue, onFalse)` |
| Shape | `Reshape Transpose Broadcast Concat Slice Reverse Pad` |
| Reduction | `Sum MaxReduce MinReduce Product` |
| Constants | `Splat Iota` |
| Quantization | `Quantize Dequantize` |

The member set is closed. `npu.` members are not declarable, shadowable, or extensible.

### 2.8 Control Flow

* `if`/`else if`/`else`/`switch`: condition/selector must be scalar (`bool`/`int32`) — no per-element branching; use `npu.Select`.
* `while`: loop-carried bindings must keep identical type, shape, and element type each iteration. `break`/`continue` are compile errors.

---

## 3. Why a Marker (and Not Just a Call-site Sigil)

Requiring `gpu`/`npu` on the function signature gives you:

* **Static, not runtime, detection.** The compiler knows at the definition site that a function's body targets device code, so it can reject constructs that don't lower to that target before you ever try to launch it.
* **No accidental host/device mismatch.** A marked function can't be called as an ordinary host function, and a plain host function can't be slipped into a `gpu(...)`/`npu` launch — the marker has to agree on both ends.
* **A scope for restricted types.** `tensor` is meaningful only under the array model. The marker gives the type somewhere to live, so its restrictions are grammar rather than prose.