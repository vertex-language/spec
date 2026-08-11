# extern.md

## Declare Struct
Introduces a layout-free type whose definition lives in C. Legal only in pointer positions.

```vertex
declare struct Sample001
```

## Declare Module
Binds a native library and triggers the linker.

```vertex
declare module "sample001" {
  export func sample002(n: uint32): int32
}
```

## Binding
There is no separate import. The `declare module` block is both the declaration and the
binder: names marked `export` inside it enter file scope directly. Go-form `import` binds
Vertex modules by path and has no named-binding form, so a foreign surface has nowhere
else to come from — and since the compiler reads no headers, the block is already the sole
source of truth.

A declaration needed in more than one file goes in a Vertex module that holds the block,
and is reached the ordinary way:

```vertex
import "app/platform/libc"
```

Same rule as `objc.md`, and for the same reason.

## Scheme-Qualified Specifier
A bare specifier links at build time against the ordinary library path. A `scheme:` prefix
selects a different resolver for the same production. Schemes are prefixes, matching
`node:`, `bun:`, `npm:`, and URI convention generally.

| Specifier | Resolver | Bound |
|---|---|---|
| `"sample001"` | library search path | link time |
| `"dynamic:libc"` | `dlopen`/`dlsym` | first use |
| `"objc:WebKit"` | framework search path | link time |
| `"jvm:java.util"` | JVM class loader | first use |

The scheme names *how the symbol is found*. The declaration keyword stays `declare module`
in every case, because what is being declared — a foreign surface taken on trust — does
not change.

## Dynamic Module Declaration
Late-bound library, resolved via `dlopen`/`dlsym` at first use rather than link time. No
link flag is emitted; the library need not be present at build time.

```vertex
declare module "dynamic:libc" {
  export func sample001(a: uint32): int32
}
```

The text after the scheme is the library name as `dlopen` would resolve it. Platform
filename decoration (`lib…so`, `…dylib`) is applied by the resolver, not written in the
specifier.

## Dynamic Resolution Failure
A dynamically-bound module can fail in ways a linked one cannot: the library may be
absent, or present without the symbol. Both surface at first use, not at launch.

Extern funcs are never fallible (see below), so this failure is not expressible as a
return union. First use of an unresolvable symbol panics — same tier as a failed
assertion, and consistent with `panic` skipping teardown.

`jvm.md` inherits this rule wholesale for `NoClassDefFoundError` and `NoSuchMethodError`,
which makes the dynamic form the general case for name-resolved schemes rather than a
special one.

Open: whether a checked form is needed — something that answers "is this symbol present"
without calling it. Deferred until a real case appears.

## Extern func Declaration
funcs inside a `declare module` block — never fallible.

```vertex
declare module "sample001" {
  export func sample002(n: uint32): int32
}
```

## Rest Parameters
Variadic extern parameters.

```vertex
declare module "sample001" {
  export func sample002(fmt: const_ptr<byte>, ...args: CVarArg): int32
}
```

The annotation is the type of each argument, not of a collection of them. C varargs are a
call-shape convention — the arguments land in registers and on the stack per the ABI, and
there is no aggregate anywhere for a collection type to describe. Nothing in an extern
declaration can index `args`, iterate it, or take its length, since the body lives in C.

This drops TS's postfix `[]`, which was the previous spelling and is now the only use of
that production in the corpus — `memory.md` covers contiguous storage with `span<T>`,
`block<T>`, and `FixedArray<T, N>`, and `jvm.md` lists arrays as open. Spelling it
`...args: span<CVarArg>` would have been worse than `[]`, not better: it asserts contiguous
storage that demonstrably does not exist at a C call boundary.

## Pointer Parameter at Extern Boundary
Declared structs are legal only behind a pointer.

```vertex
declare module "sample001" {
  export func sample002(a: mutable_ptr<Sample001>): void
}
```

## Nullability
C pointers are nullable by default; Vertex bindings are not, per `pointers.md`. An extern
declaration must therefore spell absence explicitly, and `if let` unwraps at the call site.

```vertex
declare module "dynamic:libc" {
  export func sample001(a: const_ptr<byte>): mutable_ptr<Sample002> | null
}
```

```vertex
if let a = sample001(b) {
  sample003(a)
}
```

Identical rule to `objc.md` and `jvm.md`, identical failure mode when it is wrong.

## Grammar Cost
Zero. Scheme specifiers are string literals; `declare module`, `declare struct`, and rest
parameters are existing productions. The `[]` removal in *Rest Parameters* is a
subtraction.