# numerics.md

## Sized Numeric Types
Full set of primitives — TS's `number` alongside sized, signed, unsigned, pointer-sized,
float, and raw-storage types.

```vertex
let a: int = 0
let b: int8 = 0
let c: int16 = 0
let d: int32 = 0
let e: int64 = 0
let f: uint8 = 0
let g: uint16 = 0
let h: uint32 = 0
let i: uint64 = 0
let j: usize = 0
let k: float32 = 0
let l: float64 = 0
let m: byte = 0
```

## Boolean Type
One byte of storage, two valid bit patterns. Not a numeric type — it does not participate
in arithmetic and has no conversion call.

```vertex
let a: bool = false
let b: bool = true
```

Spelled `bool` rather than TS's `boolean` — a straight rename, same as `number` → `int`.

## No Boolean/Numeric Conversion
There is no implicit conversion in either direction, and no conversion call. An integer
becomes a boolean through an explicit comparison; a boolean becomes an integer through a
conditional.

```vertex
let a: int32 = 0
let b: bool = a !== 0
let c: int32 = b ? 1 : 0
```

C's integer-boolean equivalence is the mistake being walked back here. `if (a)` on an
integer is an error — conditions require `bool`.

## Numeric Conversion Calls
Explicit call syntax required for any numeric representation change. No implicit widening
or narrowing.

```vertex
int8(a)
int16(a)
int32(a)
int64(a)
uint8(a)
uint16(a)
uint32(a)
uint64(a)
usize(a)
float32(a)
float64(a)
```

`bool` is absent from this list deliberately — see above.

## Type Assertion
Static-only assertion. Zero representation change — distinct from a conversion call.

```vertex
let a = b as uint8
```

## Numeric Literals
Underscore separators, hex literals, float literals, and signed literals.

```vertex
let a = 3_000_000_000
let b = 0xffffffff
let c = 0.0
let d = -9000000000
```

## Boolean Literals
```vertex
let a = true
let b = false
```