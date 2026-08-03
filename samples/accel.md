## Hardware Acceleration

---

## 0. Three Storage Classes

Vertex has three array-shaped storage classes. They never convert implicitly.

| Type | Lives in | Written by |
| --- | --- | --- |
| `[]T` / `[N]T` | host memory | ordinary code |
| `vector[T, N]` | one CPU SIMD register | ordinary code |
| `tensor[T, Shape...]` | accelerator buffer | `npu` bodies only |

`gpu` and `npu` are the two device-offload markers. Both say a function's body
does not run on the calling thread: it compiles to PTX / AMDTX / MSL IR for
`gpu`, or to StableHLO for `npu`.

`vector` is not a device feature at all — it is CPU SIMD, and it is illegal
inside either device marker (§3.4).

### 0.1 The two device models

| | `gpu` | `npu` |
| --- | --- | --- |
| Model | SIMT — per-thread over an index space | whole-array — ops apply to whole tensors |
| Launch shape | `(blocks:, threads:)`, optional | none — shape rides in the types |
| Body language | unrestricted Vertex | restricted (§2.3–§2.7) |
| Element access | ordinary subscripting | none — elementwise ops and `npu.` calls |
| Divergent branching | permitted | rejected — selectors must be scalar |

`npu` names a hardware *class*, exactly as `gpu` does: TPU, Trainium, the Apple
Neural Engine, Hexagon, Intel and AMD NPUs. No vendor name appears in Vertex
source; the toolchain picks the device.

---

## 1. GPU

### 1.1 Marker

```vertex
func matrixMult(x: []float32, y: []float32) gpu -> []float32 {
    // ordinary Vertex — no restricted types, no restricted constructs
}
```

### 1.2 Call site

```vertex
let d = gpu(blocks: 16, threads: 256) matrixMult(x, y)   // explicit shape
let e = gpu matrixMult(x, y)                             // default shape
```

A launch config, where written, must supply **both** `blocks:` and `threads:`.

### 1.3 Return values

Host-typed arguments in, a plain host-typed result out — an ordinary,
synchronous call.

---

## 2. NPU

### 2.1 Marker and call site

```vertex
func vecAdd(a: tensor[float32, 1024], b: tensor[float32, 1024])
    npu -> tensor[float32, 1024] {
    return a + b
}

var ha: [1024]float32
var hb: [1024]float32

let sum = npu vecAdd(ha, hb)    // sum: [1024]float32
```

Host arrays pass in as the `tensor`-typed parameters; a plain host array comes
back. Same synchronous shape as `gpu` (§1.3).

The marker must agree at both ends, for both markers: a marked function cannot
be called bare, and an unmarked one cannot be called with a launch prefix.

`npu` immediately followed by `.` is the builtin namespace (§2.6), never a
launch prefix — same treatment `async` and `gpu` get.

### 2.2 `tensor[ElementType, Shape...]`

* Legal only inside an `npu` body or that function's own signature.
* **Signature-eligible:** `float32`, `int8`. **Body-only:** `bf16`, `fp8e4m3`,
  `fp8e5m2`, `int4`.
* **Shape:** one or more constant integer literals, comma-separated after the
  element type — `tensor[float32, 1024]`, `tensor[float32, 16, 16]`.
* No subscripting. `a[i]` is an error in every form.

### 2.3 Elementwise operators

`+ - * /` and unary `-`; comparisons `== != < <= > >=` yield
`tensor[bool, Shape...]`. Operands must agree exactly in element type and
shape — there is no broadcasting, only `npu.Broadcast`.

### 2.4 Casting and quantization

* Plain casts (`bf16(val)`) saturate on overflow into `int8` / `int4`.
* `npu.Quantize[T](a, scale)` / `npu.Dequantize[T](a, scale)` — scalar-scaled
  conversion between `float32` and `int8` / `fp8` / `int4`.

### 2.5 Control flow

* `if` / `else` / `switch`: the condition or selector must be scalar
  (`bool` / `int32`). Per-element choice is `npu.Select`.
* `while`: every loop-carried binding keeps identical type, shape, and element
  type each iteration. `break` and `continue` are errors.

### 2.6 The `npu.` namespace

| Category | Members |
| --- | --- |
| Math | `Abs Sign Floor Ceil Round Sqrt Rsqrt Exp Expm1 Log Log1p Sin Cos Tan Tanh Sigmoid IsFinite Max Min Mod Pow Atan2` |
| Contraction | `Dot(a, b)` — accumulates in `float32` regardless of input precision |
| Selection | `Select(cond, onTrue, onFalse)` |
| Shape | `Reshape Transpose Broadcast Concat Slice Reverse Pad` |
| Reduction | `Sum MaxReduce MinReduce Product` |
| Constants | `Splat Iota` |
| Quantization | `Quantize Dequantize` |

The set is closed. Members are not declarable, shadowable, or extensible.

### 2.7 A worked body

```vertex
func attention(q: tensor[float32, 128, 64],
               k: tensor[float32, 128, 64],
               scale: float32) npu -> tensor[float32, 128, 128] {
    let kt = npu.Transpose(k)
    let s  = npu.Dot(q, kt)
    let e  = npu.Exp(s - npu.Broadcast(npu.MaxReduce(s)))
    return e / npu.Broadcast(npu.Sum(e))
}
```

---

## 3. Vector — CPU SIMD

`vector[T, N]` is one SIMD register on the calling thread. It is in this
document only to mark the boundary: it is *not* an accelerator type.

### 3.1 Well-formedness

* `T` is a scalar numeric type — `int8`…`int64`, `uint8`…`uint64`, `float32`,
  `float64`. Nothing else.
* `N` is an integer literal from `{2, 4, 8, 16, 32, 64}`.

### 3.2 Construction, store, extraction

```vertex
let v = vector[float32, 8](1.5)        // splat — every lane
let w = vector[float32, 8](buf, 0)     // load — 8 elements from index 0
let i = vector[int32, 8](w)            // lane conversion, same N

copy(out[0..8], v)                     // store into a slice view of length 8
let first = v[0]                       // extract — constant index only
```

The load is bounds-checked at runtime; a constant index provably out of range
on a fixed array is a compile error instead.

### 3.3 Operations and the lane predicate

```vertex
let sum = v + w                        // lane-wise
let m   = v < w                        // lane predicate, not bool
let r   = blend(m, v, w)
let c   = clamp(r, lo, hi)
```

A lane predicate has no source spelling and no signature position. It cannot be
an `if` condition, a `&&` operand, a field, or a channel element — it exists
only between a comparison and a `blend`.

`blend`, `min`, `max`, and `clamp` are free functions, never methods.

### 3.4 Vectors and device code do not mix

`vector[T, N]` is an **error** inside a `gpu` or `npu` body, and in either
marker's signature. It is likewise an error at a foreign boundary and as a
`map` key.

```vertex
func bad(v: vector[float32, 8]) gpu -> float32 { ... }   // error
func alsoBad() npu -> tensor[float32, 8] {
    let v = vector[float32, 8](1.0)                      // error
}
```

The reason is that these are three parallelism models, not one: device
parallelism is the device's job, tensor shape is the array model's, and
`vector` is the host thread's own register file.

---

## 4. Why a Marker and Not Just a Call-Site Sigil

* **Static detection.** The compiler knows at the *definition* site that the
  body targets device code, so it rejects non-lowerable constructs before any
  launch exists.
* **No host/device mismatch.** The marker must agree at both ends, in both
  directions.
* **A scope for restricted types.** `tensor` is meaningful only under the array
  model. The marker gives it somewhere to live, so its restrictions are grammar
  rather than prose.