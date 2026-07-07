# Vertex Language Grammar

## Specification 2.2 — Hardware Acceleration Extensions

---

## 1. GPU Extension

​```vertex
let d = gpu(blocks: 16, threads: 256) matrix_mult(x, y)
​```

* `gpu` sigil, optional config `(blocks: n, threads: n)` → compiles to PTX/SPIR-V.
* Function body is ordinary Vertex — no restricted types/constructs.
* Return-type channeling: same rule as any sigil'd call (see `concurrency.md` §3).

---

## 2. TPU Extension

​```vertex
func vecAdd(a: tensor<float32; 1024>, b: tensor<float32; 1024>) -> tensor<float32; 1024> {
    return a + b
}

var ha: [float32; 1024]
var hb: [float32; 1024]

let sum = tpu vecAdd(ha, hb)   // sum: [float32; 1024]
​```

`tpu` sigil channels a host array call into a `tensor`-typed function body, and channels the `tensor` result back to a plain host array — same return-type-channeling rule as `gpu`.

### 2.1 `tensor<ElementType; Shape>`

* Valid only inside a `tpu`-sigil function body.
* **Signature-eligible:** `float32`, `int8`. **Body-only:** `bf16`, `fp8e4m3`, `fp8e5m2`, `int4`.
* **Shape:** one or more compile-time integer literals.
* No subscripting (`a[i]` is a compile error) — element access only via elementwise ops and `tpu.` calls.

### 2.2 Elementwise Operators

`+ - * /` unary `-`; comparisons `== != < <= > >=` → `tensor<bool; Shape>`. Operands must share element type and shape.

### 2.3 Casting & Quantization

* Plain casts (e.g. `bf16(val)`) saturate on overflow into `int8`/`int4`.
* `tpu.Quantize<T>(a, scale)` / `tpu.Dequantize<T>(a, scale)` — scalar-scaled conversion between `float32` and `int8`/`fp8`/`int4`.

### 2.4 `tpu.` Builtin Namespace (reference)

| Category | Members |
|---|---|
| Math | `Abs Sign Floor Ceil Round Sqrt Rsqrt Exp Expm1 Log Log1p Sin Cos Tan Tanh Sigmoid IsFinite Max Min Mod Pow Atan2` |
| Contraction | `Dot(a, b)` — accumulates in `float32` regardless of input precision |
| Selection | `Select(cond, onTrue, onFalse)` |
| Shape | `Reshape Transpose Broadcast Concat Slice Reverse Pad` |
| Reduction | `Sum MaxReduce MinReduce Product` |
| Constants | `Splat Iota` |

### 2.5 Control Flow

* `if`/`else if`/`else`/`switch`: condition/selector must be scalar (`bool`/`int32`) — no per-element branching, use `tpu.Select`.
* `while`: loop-carried bindings must keep identical type/shape/element type each iteration. `break`/`continue` are compile errors.