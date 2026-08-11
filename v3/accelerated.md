# accelerated.md

## Kernel Function Declaration
SIMT, side-effecting execution model. Lowers to PTX or MSL depending on file target.

```vertex
kernel func sample001(): void {
}
```

## Graph Function Declaration
Pure dataflow model over whole tensors. No thread context. Lowers to a StableHLO string.

```vertex
graph func sample001(): Tensor<float32, 1> {
}
```

## Exported Kernel Function
Kernels are nameable to the compiler but not callable by host code — invoked only through `compile`/`launch`.

```vertex
export kernel func sample001(a: device_ptr<float32>, n: int32): void {
}
```

## Exported Graph Function
Callable directly once compiled — no launch configuration required.

```vertex
export graph func sample001(a: Tensor<float32, 128, 64>): Tensor<float32, 128, 64> {
  return a
}
```

## Device Pointer Type
Legal only inside a `kernel func` body, alongside thread-context intrinsics.

```vertex
let a: device_ptr<float32>
```

## Thread Context Intrinsics
Legal only inside a `kernel func` body.

```vertex
threadIdx.x
blockIdx.x
blockDim.x
gridDim.x
```

## SIMD Type
Trivially copyable, no modifier, no file-level directive required.

```vertex
let a: simd<float32, 4>
```

## Tensor Type
Shape-encoded value type used exclusively in the graph route.

```vertex
let a: Tensor<float32, 128, 64>
```

## Compile Call
Lowers a kernel or graph function into its target-specific compiled form.

```vertex
let a = compile(sample001)
```

## Launch Call
Invokes a compiled kernel with an explicit dimension configuration.

```vertex
launch(config, a, b, c, n)
```