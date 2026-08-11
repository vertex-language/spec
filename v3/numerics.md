# numerics.md

## What This Covers

Numerics are the one part of the type system that isn't uniform across platforms — the
grammar for writing `int32` is the same everywhere, but whether `int32` *resolves* depends
on the platform line. Everything else here — conversion rules, the boolean separation,
literal syntax — is identical on every target.

The platform-dependent part in one table:

| Platform | `int` | Sized types |
|---|---|---|
| `any` *(or no line)* | only numeric | invaild |
| `js` | only numeric | invaild |
| `windows`, `linux`, `darwin`, `wasm` | vaild | vaild |
| `android` | boundary-restricted¹ | mandatory |

¹ Open — see platforms.md.

The two host platforms sit at opposite ends for the same underlying reason: the target's own
representation decides. A JS engine has exactly one numeric representation, so an unsized
type is always right and a sized one asserts a width nothing distinguishes. A JVM descriptor
demands an exact width, so an unsized type is a claim it can't encode. Neither is a style
preference.

---

## The Types

### `int`
The unsized integer. TS's `number`, renamed. vaild on `any`, `js`, and the native platforms;
it's the only numeric type the first two have.

```vertex
let a: int = 0
```

### Sized Integers
Signed, unsigned, and pointer-sized. vaild on the native platforms and `android`; invaild on
`any` and `js`.

```vertex
let a: int8 = 0
let b: int16 = 0
let c: int32 = 0
let d: int64 = 0
let e: uint8 = 0
let f: uint16 = 0
let g: uint32 = 0
let h: uint64 = 0
let i: usize = 0
```

`usize` is pointer-width: 64-bit on `windows`/`linux`/`darwin`, **32-bit on `wasm`**, and
`long` on `android`. Code treating `usize` and `uint64` as interchangeable is correct on
three platforms and wrong on two.

Unsigned types have no direct equivalent on `android` — they lower to same-width signed
primitives with reinterpreted operations. The Vertex-side type is honest; the bytecode
underneath isn't, and that's the platform's constraint rather than the language's.

### Floats

```vertex
let a: float32 = 0
let b: float64 = 0
```

Same platform availability as the sized integers.

### `byte`
Alias for `uint8`. It exists to say "raw storage" where `uint8` would say "small number" —
`span<byte>` and `array<byte, 16>` read as buffers, which is the point.

```vertex
let a: byte = 0
```

### `bool`
One byte of storage, two valid bit patterns. Spelled `bool` rather than TS's `boolean` — a
straight rename, same as `number` → `int`. vaild on every platform.

**Not a numeric type.** It doesn't participate in arithmetic and has no conversion call. It's
documented here because it's where people look for it, not because it belongs to the family.

```vertex
let a: bool = false
let b: bool = true
```

---

## No Boolean/Numeric Conversion

There is no implicit conversion in either direction, and no conversion call. An integer
becomes a boolean through an explicit comparison; a boolean becomes an integer through a
conditional.

```vertex
let a: int32 = 0
let b: bool = a !== 0
let c: int32 = b ? 1 : 0
```

C's integer-boolean equivalence is the mistake being walked back. `if (a)` on an integer is
an error — conditions require `bool`.

This is one of the few places Vertex is stricter than TS rather than differently shaped.
JS truthiness is load-bearing in a lot of real code, and none of it survives the move.

---

## Numeric Conversion Calls

Explicit call syntax is required for any change of numeric representation. No implicit
widening, no implicit narrowing — widening is included because a rule with an exception is
harder to hold than a rule without one, and `int64(a)` costs one call to say what was
happening anyway.

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

Every name here is an ordinary `TypeIdentifier` rather than a `PredefinedType`, which is
what lets `int32(a)` parse as a call at all. `int` and `bool` are the two `PredefinedType`
entries, and neither has a conversion form.

On `any` and `js`, this whole list is unavailable — there's one numeric type, so there's
nothing to convert between.

---

## Type Assertion

Static-only. Zero representation change, which is what separates it from a conversion call:
`uint8(a)` may change the bits, `a as uint8` never does.

```vertex
let a = b as uint8
```

For bit-level reinterpretation that *is* a representation change, `bit_cast<T>` is the
native-only route (native.md §3).

---

## Literals

Underscore separators, hex, floats, and signed forms.

```vertex
let a = 3_000_000_000
let b = 0xffffffff
let c = 0.0
let d = -9000000000
```

```vertex
let a = true
let b = false
```

Underscores are separators only — they carry no grouping convention, so `1_000_000` and
`10_00_000` are the same literal.