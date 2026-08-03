## Hardware Acceleration

---

## 0. Three Storage Classes

Vertex has three array-shaped storage classes. They never convert implicitly, and
each belongs to a different execution model.

| Type | Lives in | Written by |
| --- | --- | --- |
| `[]T` / `[N]T` | host memory | ordinary code |
| `vector[T, N]` | one CPU SIMD register | ordinary code |
| `tensor[T, Shape...]` | accelerator buffer | `npu` bodies only |

`gpu` and `npu` are the two device-offload markers. Both say a function's body does
not run on the calling thread: it compiles to PTX / AMDTX / MSL IR for `gpu`, or to
StableHLO for `npu`.

`vector` is not a device feature at all — it is CPU SIMD, and it is illegal inside
either device marker (§3.4).

### 0.1 The two device models

| | `gpu` | `npu` |
| --- | --- | --- |
| Model | SIMT — per-thread over an index space | whole-array — ops apply to whole tensors |
| Launch shape | `(blocks:, threads:)`, optional | none — shape rides in the types |
| Body language | unrestricted Vertex | restricted (§2.3–§2.7) |
| Element access | ordinary subscripting | none — elementwise ops and `npu.` calls |
| Divergent branching | permitted | rejected — selectors must be scalar |

`npu` names a hardware *class*, exactly as `gpu` does: TPU, Trainium, the Apple
Neural Engine, Hexagon, Intel and AMD NPUs. No vendor name appears in Vertex source;
the toolchain picks the device.

### 0.2 Markers and Namespaces Share a Spelling

`async`, `gpu`, and `npu` are each both a launch prefix and a namespace name. One
token of lookahead separates them (grammar, *Launch expressions*): a following `"."`
makes it a namespace, anything else makes it a launch prefix.

```vertex
let s = npu.Dot(a, b)          // namespace member call, inside an npu body
let r = npu vecAdd(ha, hb)     // launch prefix, at a call site
```

`thread` is not a namespace and needs no lookahead.

---

## 1. GPU

### 1.1 Marker

A `gpu` body is ordinary Vertex. The marker changes where the body runs, not what is
legal inside it — with the one exception in §3.4.

```vertex
func matrixMult(x: []float32, y: []float32) gpu -> []float32 {
    var out: []float32 = []
    // ordinary Vertex — no restricted types, no restricted constructs
    return out
}
```

### 1.2 Call site

```vertex
let d = gpu(blocks: 16, threads: 256) matrixMult(x, y)   // explicit shape
let e = gpu matrixMult(x, y)                             // default shape
```

A `LaunchConfig`, where written, must supply **both** `blocks:` and `threads:`, in
that order. It has fixed arity and fixed names and is not a general argument list —
`gpu(blocks: 16)` and `gpu(threads: 256, blocks: 16)` are both syntax errors.

### 1.3 Return values

Host-typed arguments in, a plain host-typed result out — an ordinary, synchronous
call. The launch does not hand back a `chan T`; that is `thread` and `async`
(channels §2), and it is the one place the three prefixes visibly diverge.

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

Host arrays pass in as the `tensor`-typed parameters; a plain host array comes back.
Same synchronous shape as `gpu` (§1.3).

**The host↔tensor conversion at the launch boundary is the language's only implicit
conversion.** Foundation §6 admits no implicit numeric conversion and §0 above says
the three storage classes never convert implicitly — both hold *inside* a body. At a
launch, a `[N]T` argument becomes the declared `tensor[T, N]` parameter and the
`tensor` result becomes a `[N]T`, with no cast written. The element type must match
exactly and the shape must match exactly; nothing is widened, reshaped, or
broadcast. This is a stated exception, and it is confined to a launch site.

The marker must agree at both ends, for both markers: a marked function cannot be
called bare, and an unmarked one cannot be called with a launch prefix.

### 2.2 `tensor[ElementType, Shape...]`

* Legal only inside an `npu` body or that function's own signature.
* **Signature-eligible:** `float32`, `int8`. **Body-only:** `bf16`, `fp8e4m3`,
  `fp8e5m2`, `int4`.
* **Shape:** one or more integer *literals*, comma-separated after the element type
  — `tensor[float32, 1024]`, `tensor[float32, 16, 16]`. `ShapeList` is
  `int_lit { "," int_lit }` (grammar, *Tensor and vector types*), so a named
  constant is not admissible even when its value is known at compile time.
* No subscripting. `a[i]` is an error in every form.

The body-only element types are predeclared identifiers legal solely as a
`TensorType`'s element type inside an `npu` body and as a cast target there
(`bf16(val)`). Everywhere else they parse and are rejected — including in a
signature, which is what keeps a low-precision type from crossing a launch boundary
where the host has no matching array type.

### 2.3 Elementwise operators

`+ - * /` and unary `-`; comparisons `== != < <= > >=` yield
`tensor[bool, Shape...]`. Operands must agree exactly in element type and shape —
there is no broadcasting, only `npu.Broadcast`.

`bool` is signature-ineligible as a tensor element type for the same reason the
low-precision types are: a comparison result is a value the body consumes, via
`npu.Select` or a reduction, not one it returns.

### 2.4 Casting and quantization

* Plain casts (`bf16(val)`) saturate on overflow into `int8` / `int4`. This is the
  constructor spelling, which foundation §6.1 withholds from the predeclared numeric
  types — the tensor element types are the exception, and `val as bf16` is not the
  form here.
* `npu.Quantize[T](a, scale)` / `npu.Dequantize[T](a, scale)` — scalar-scaled
  conversion between `float32` and `int8` / `fp8` / `int4`.

### 2.5 Control flow

* `if` / `else` / `switch`: the condition or selector must be scalar
  (`bool` / `int32`). Per-element choice is `npu.Select`.
* `while`: every loop-carried binding keeps identical type, shape, and element type
  each iteration. `break` and `continue` are errors.

The restriction is what makes the body lowerable: a whole-array program has no
per-lane program counter to diverge, so a branch on a tensor has no meaning to give
it. `while` survives because a loop whose carried shapes are stable unrolls to a
fixed graph; `break` would make the trip count data-dependent.

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

`npu.` members are reached through a `Selector` on a `NamespaceName` (§0.2), so they
are not identifiers in any scope — they cannot collide with a user declaration and
do not need to be reserved builtin names the way `min`, `max`, `blend`, and `clamp`
do (§3.3).

### 2.7 A worked body

Softmax-scaled attention, in the restricted subset:

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

Every line is either an elementwise operator (§2.3) or an `npu.` call (§2.6). The
two `npu.Broadcast` calls are what §2.3's no-broadcasting rule forces: `MaxReduce`
and `Sum` produce a reduced shape, and subtracting or dividing by it requires
restoring the operand shape explicitly.

`scale` is declared and unused — see §5.

---

## 3. Vector — CPU SIMD

`vector[T, N]` is one SIMD register on the calling thread. It is in this document
only to mark the boundary: it is *not* an accelerator type, and nothing about it
involves a launch, a device, or a marker.

### 3.1 Well-formedness

* `T` is a scalar numeric type — `int8`…`int64`, `uint8`…`uint64`, `float32`,
  `float64`. Nothing else.
* `N` is an integer literal from `{2, 4, 8, 16, 32, 64}`.

A `VectorType` is grammatically legal wherever a `Type` is; where it may actually
appear is the static rule in §3.4.

### 3.2 Construction, store, extraction

A `VectorCall`'s callee is a `VectorType`, not an ordinary name, and it has exactly
two forms (grammar, *Type-operator and constructor calls*):

```vertex
let v = vector[float32, 8](1.5)        // one argument  — splat, every lane
let w = vector[float32, 8](buf, 0)     // two arguments — load 8 elements from index 0
let i = vector[int32, 8](w)            // one argument, vector operand — lane conversion
```

The one-argument form splats a scalar and converts a vector, distinguished by the
operand's type; `N` is unchanged by a conversion.

```vertex
let first = v[0]                       // extract — constant index only
```

Extraction is an `Index` whose expression must be an integer literal in `0..N`. A
non-constant index is a compile error, not a runtime lookup: a lane number is part
of the instruction, not a value it takes.

The load form is bounds-checked at runtime; a constant index provably out of range
on a fixed array is a compile error instead.

**Storing back to memory is unspecified.** There is no `.store` method, no
assignment form from a vector to a slice, and no `copy` overload that accepts one —
`copy` takes two `typed_ptr T` and a count (memory §12.1). See §5.

### 3.3 Operations and the lane predicate

```vertex
let sum = v + w                        // lane-wise
let m   = v < w                        // lane predicate, not bool
let r   = blend(m, v, w)
let c   = clamp(r, lo, hi)
```

A lane predicate has no source spelling and no signature position. It cannot be an
`if` condition, a `&&` operand, a field, or a channel element — it exists only
between a comparison and a `blend`.

`blend`, `min`, `max`, and `clamp` are free functions, never methods. All four are
reserved builtin names (grammar, *Reserved builtin names*): they may not be
shadowed or redeclared, generically or otherwise, which is why generics §4's example
is called `smaller` rather than `min`.

Their exact signatures are unspecified; see §5.

### 3.4 Vectors and device code do not mix

`vector[T, N]` is an **error** inside a `gpu` or `npu` body, and in either marker's
signature. It is likewise an error at a foreign boundary and as a `map` key.

```vertex
func bad(v: vector[float32, 8]) gpu -> float32 {
    return 0.0                                           // error: signature
}

func alsoBad() npu -> tensor[float32, 8] {
    let v = vector[float32, 8](1.0)                      // error: body
    return npu.Splat(0.0)
}
```

The reason is that these are three parallelism models, not one: device parallelism
is the device's job, tensor shape is the array model's, and `vector` is the host
thread's own register file. A `vector` inside a `gpu` body would name a register on
a machine that is not running the body.

The `map` key exclusion follows from `comparable` (generics §3.4): a lane-wise `==`
on two vectors yields a lane predicate, not a `bool`, so a vector has no equality a
map can key on.

---

## 4. Why a Marker and Not Just a Call-Site Sigil

* **Static detection.** The compiler knows at the *definition* site that the body
  targets device code, so it rejects non-lowerable constructs before any launch
  exists.
* **No host/device mismatch.** The marker must agree at both ends, in both
  directions, and it is part of the function's type (foundation §31) — so a
  `func(...) npu -> ...` stored in a variable carries the marker with it.
* **A scope for restricted types.** `tensor` is meaningful only under the array
  model. The marker gives it somewhere to live, so its restrictions are grammar
  rather than prose.

A signature carries at most one marker (grammar, *Function types and signatures*):
there is no `async gpu` function, and a device body that needs to await something
does not exist. Overlapping the two is the wrapper's job on the host side.