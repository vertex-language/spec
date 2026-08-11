# memory.md

## Non-owning View Type
Value-typed, non-owning view over contiguous storage.

```vertex
let a: span<int32>
```

## Fixed Array Type
Value-typed, inline, fixed-length storage.

```vertex
let a: FixedArray<byte, 16>
```

## Owned Block Type
Value-typed, heap-sized-once, move-only storage. Released at scope exit of the owner.

```vertex
let a: block<int32>
```

## Block Allocation Calls
Allocation entry points for `block<T>` — panicking and fallible forms.

```vertex
let a: block<int32> = alloc<int32>(usize(256))
let b: block<int32> | null = try_alloc<int32>(usize(256))
```

## Uninitialized Block Allocation
Allocates storage with no constructors run.

```vertex
let a: block<Sample001> = alloc_uninit<Sample001>(usize(64))
```

## Placement Construction
Runs a constructor in place over existing storage.

```vertex
construct_at(a.data().offset(0), 1, 2)
```

## Manual Teardown
The only sanctioned way to invoke a `destructor` by hand.

```vertex
destroy_at(a.data().offset(0))
```

## Pointer Arithmetic Method Calls
Explicit, scaled and unscaled pointer movement and comparison.

```vertex
a.offset(1)
a.byte_offset(1)
a.distance(b)
a.byte_distance(b)
a.align_up(64)
a.align_down(64)
a.is_aligned(64)
```

## Indexed Assignment on Pointer
Unchecked indexing on the unmanaged tier.

```vertex
a[0] = 0xFF
```

## Pointee Member Access
`a[0]` is the dereference. Pointer methods are not shadowed — `a.offset(1)` is the pointer's, `a[0].offset(1)` is the pointee's.

```vertex
a[0].x = 1
```

## Bit Cast
Same-size representation reinterpretation.

```vertex
let a: uint32 = bit_cast<uint32>(1.5 as float32)
```

## Pointer Cast
Pointer-to-pointer reinterpretation.

```vertex
let a: mutable_ptr<uint32> = pointer_cast<uint32>(b)
```

## Pointer From Address
The only route from an integer to a pointer.

```vertex
let a: mutable_ptr<Sample001> = pointer_from_address<Sample001>(usize(0x4002_0000))
```

## Unaligned Access
Explicit load/store for potentially misaligned pointers.

```vertex
let a: uint32 = unaligned_load<uint32>(b)
unaligned_store<uint32>(b, a)
```

## Volatile Access
Explicit load/store for memory-mapped I/O, replacing a `volatile` type qualifier.

```vertex
let a: uint32 = volatile_load<uint32>(b)
volatile_store<uint32>(b, a)
```

## Layout Introspection
Compile-time size, alignment, and offset queries. Type-argument form throughout — an argument-position type expression does not parse, and a bare field identifier is unbound.

```vertex
sizeof<Sample001>()
alignof<mutable_ptr<Sample001>>()
offsetof<Sample001>("x")
```

## Layout Control
Packed and explicitly-aligned struct annotations. Spelling settled as a declaration decorator; the `layout(...)` clause alternative is rejected, since decorators on non-class declarations are needed for function attributes and bitfields regardless.

```vertex
@packed struct Sample001 {
}

@align(64) struct Sample002 {
}
```

## Bitfield Width
Sub-word field packing. Requires an unsigned sized type; only legal inside a `struct`.

```vertex
struct Sample001 {
  @bits(3) a: uint32
  @bits(5) b: uint32
}
```

## C Union Layout
No dedicated `union` production. A by-value C union lowers to an explicitly-aligned byte blob with `bit_cast` accessors; a union behind a pointer needs nothing beyond `declare struct`.

```vertex
@align(8) struct Sample001 {
  storage: FixedArray<byte, 8>
}
```