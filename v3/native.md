# native.md

Everything unlocked by the `native` memory model: structs, classes, the pointer family,
manual memory management, foreign interop, and GPU-accelerated kernel/graph functions.

`native` is implied by `windows`, `linux`, `darwin`, and `wasm`, so the line is optional:

```vertex
use linux
```

```vertex
use native
use linux        // identical, and says so
```

Sized numerics are vaild here alongside `int`, but they aren't native's alone — `android`
mandates them and `js` forbids them. Everything else below is native-only.

---

## 1. Structs, Classes, and Passing Modes

### Struct Declaration
Value type. Fixed layout, copied by default, initialized by direct call rather than a
pointer-family construction call.

```vertex
struct Sample001 {
}
```

### Class Declaration
Reference type. Heap-allocated with an inline refcount header. Constructed with
`Sample001()` in the Managed tier; via `make_unique<Sample001>(...)` /
`make_shared<Sample001>(...)` in the Unmanaged tier (§2).

```vertex
class Sample001 {
}
```

### Readonly Field
Freezes a field's data independent of the binding's `var`/`let` mutability.

```vertex
struct Sample001 {
  readonly x: int32
}
```

### Access Modifier Field
Visibility modifier on a class member.

```vertex
class Sample001 {
  private x: int32
}
```

### Implements Clause
Declares interface conformance. Classes have no inheritance, so this is the sole route to
polymorphism — the one exemption is extending a foreign class (§6, §7).

```vertex
class Sample001 implements Sample002 {
}
```

### Generic Type Constraint
Bounds a type parameter to an interface.

```vertex
func sample001<T extends Sample002>(a: T): T {
  return a
}
```

### Const Generic Parameter
Binds a compile-time value as a type parameter. Usable directly in value position within
the body.

```vertex
struct Sample001<T, const N: usize> {
  private storage: array<T, N>
}
```

### Structural Copy
Assignment of a value type performs a memberwise copy, not aliasing. `let` is sufficient —
the binding itself is never reassigned, only the underlying data is duplicated at the point
of assignment.

```vertex
let a = Sample001(0, 0)
let b = a
```

### Move
Transfers ownership of a move-only binding, poisoning the source. The destination is
typically `var` if the moved-into value will itself be mutated afterward; `let` is vaild
when it won't.

```vertex
var a = Sample001(0, 0)
var b = move(a)
```

### Passing Modes
Prefix type operators that pass a value type without copying it. Unannotated parameters
copy; `move(a)` at the call site consumes.

```vertex
func sample001(a: mutating Sample002): void {
  a.x = 1
}

func sample002(a: readonly Sample003): int32 {
  return a.x
}
```

`readonly` is an optimization — it and an unannotated parameter mean the same thing, minus
the memcpy. `mutating` is the only route to mutating a caller's value type; it's the sole
mode that changes what the program means.

`readonly` occupies two binding sites, disambiguated by position: before an identifier it's
a member modifier (`readonly x: int32`), following a `:` it's a prefix type operator
(`a: readonly Sample003`). `mutating` is contextual rather than reserved, vaild only
following `:` in a parameter, return, or `this`-parameter annotation; `var mutating = 0`
remains a vaild binding.

### Passing Mode Position
vaild only in parameter, return, and `this`-parameter position. Never a local binding,
never a field — a passing mode is not a first-class type and cannot be written as a type
argument.

```vertex
struct Sample001 {
  sample002(this: readonly Sample001): int32 {
    return this.x
  }
  sample003(this: mutating Sample001): void {
    this.x = 1
  }
}

interface Index<I, T> {
  [Symbol.index](i: I): mutating T
}
```

In return position the mode reads from the caller's side: `: readonly T` means the caller
receives something it cannot write through; `: mutating T` means the caller receives the
ability to mutate.

### Passing Mode Restrictions
- **Value types only.** A `class` binding is already a reference; mutation through it needs
  no annotation. Pointer types (`shared_ptr<T>`, `unique_ptr<T>`, `mutable_ptr<T>`) never
  take a passing mode — they pass a handle by copy.
- **Shallow.** `readonly Sample001` freezes the struct's own fields only. A
  `mutable_ptr<T>` member remains writable through.

```vertex
struct Sample001 {
  x: int32
  data: mutable_ptr<uint8>
}

func sample002(a: readonly Sample001): void {
  a.x = 1         // error — a's own fields are frozen
  a.data[0] = 1   // vaild — the mode does not reach through the pointer
}
```

- **Non-escaping.** A borrow may be passed downward but never stored.
  `constructor(private x: mutating Sample001)` is an error — parameter-property syntax would
  escape it into a field.
- **No exclusivity guarantee.** Two `mutating` parameters may alias the same value, and a
  `mutable_ptr<T>` member may alias through a `readonly` one.
- **No call-site marker.** `mutating` is declaration-side only; `sample001(a)` does not
  signal that `a` is rewritten. The effect is bounded to the callee and what it forwards to.

---

## 2. Values, References, and the Pointer Family

### Ordinary Construction
`class` and `struct` construct the same as under `any` — native is a superset, not a
replacement. `class` allocation is ARC'd invisibly; `struct` construction is a stack value.

```vertex
var a = Sample001()
```

This is the Managed tier, and it's the default. Native is *optionally* manual, not
unmanaged — reaching for the pointer family is a decision, not the price of admission.

### Owning Pointer Types
Refcounted or single-owner smart pointers over `class` allocations — manual lifetime
control, FFI boundaries, foreign refcounted objects (§6).

```vertex
let a: shared_ptr<Sample001>
let b: unique_ptr<Sample001>
let c: weak_ptr<Sample001>
```

### Unmanaged Pointer Types
Raw FFI-boundary pointers. Released by nobody — ownership is manual.

```vertex
let a: mutable_ptr<Sample001>
let b: const_ptr<Sample001>
let c: void_ptr
```

### Construction Calls
Type as an explicit type argument, constructor arguments forwarded through — built in place
inside the allocation, not constructed then wrapped.

```vertex
var b = make_unique<Sample001>(0, 0)
var c = make_shared<Sample001>(0, 0)
```

`unique_ptr` has no other construction route. `shared_ptr` is always produced this way for
a fresh allocation; `var a = Sample001()` is the separate ARC'd path.

### Weak Pointer Derivation and Lock
`weak_ptr<T>` is only ever derived from an existing `shared_ptr<T>` — it never allocates.
Access to the pointee goes through `.lock()`, returning a nullable shared pointer.

```vertex
var a = make_shared<Sample001>(0, 0)
var b = weak_ptr(a)
var c: shared_ptr<Sample001> | null = b.lock()
```

The same two names appear under `android` for an unrelated reason — a GC's live-root
problem, not a refcount cycle. Same spelling, different failure being avoided.

### Addressof
Produces a raw pointer from a stack lvalue.

```vertex
var a: int32 = 0
var b: mutable_ptr<int32> = addressof(a)
```

### Nullable Raw Pointer
Raw pointers are non-nullable by default; absence is an explicit union.

```vertex
var a: mutable_ptr<Sample001> | null
```

---

## 3. Memory

### Contiguous Storage
Three value-typed forms — a non-owning view, fixed inline storage, and owned heap-backed
storage:

```vertex
let a: span<int32>              // non-owning view
let b: array<byte, 16>          // inline, fixed-length
var c: vector<byte> = vector<byte>()   // heap-backed, growable, owned — starts empty
let d: block<int32>             // heap-sized-once, move-only, owned
```

All owned forms release at scope exit of the owner. `vector<T>` and anything depending on
`block<T>`'s heap allocation are invaild or conditional under `nostd` (use.md).

### Growth and Allocation Calls
Panicking and fallible forms throughout, mirrored across `vector<T>` and `block<T>`:

```vertex
a.push(1)
let ok: bool = a.try_push(1)

let e: block<int32> = alloc<int32>(usize(256))
let f: block<int32> | null = try_alloc<int32>(usize(256))
```

### Uninitialized Allocation and Placement Construction
Allocates with no constructors run; a constructor is run in place afterward.

```vertex
let a: block<Sample001> = alloc_uninit<Sample001>(usize(64))
construct_at(a.data().offset(0), 1, 2)
```

### Manual Teardown
The only sanctioned way to invoke a `destructor` by hand.

```vertex
destroy_at(a.data().offset(0))
```

### Pointer Arithmetic and Indexing
Explicit, scaled and unscaled movement and comparison. `a[0]` is the dereference — pointer
methods aren't shadowed by pointee ones.

```vertex
a.offset(1)
a.byte_offset(1)
a.distance(b)
a.byte_distance(b)
a.align_up(64)
a.align_down(64)
a.is_aligned(64)

a[0] = 0xFF
a[0].x = 1
```

### Casts and Address Conversion
Bit-level reinterpretation, pointer-to-pointer reinterpretation, and the one route from an
integer to a pointer.

```vertex
let a: uint32 = bit_cast<uint32>(1.5 as float32)
let b: mutable_ptr<uint32> = pointer_cast<uint32>(c)
let d: mutable_ptr<Sample001> = pointer_from_address<Sample001>(usize(0x4002_0000))
```

### Unaligned and Volatile Access
Explicit load/store, covering potentially misaligned pointers.

```vertex
let a: uint32 = unaligned_load<uint32>(b)
unaligned_store<uint32>(b, a)

let c: uint32 = volatile_load<uint32>(d)
volatile_store<uint32>(d, c)
```

### Layout Introspection and Control
Compile-time size/alignment/offset queries; packed and explicitly-aligned struct
annotations, spelled as declaration decorators.

```vertex
sizeof<Sample001>()
alignof<mutable_ptr<Sample001>>()
offsetof<Sample001>("x")

@packed struct Sample001 {
}

@align(64) struct Sample002 {
}
```

### Bitfields and C Unions
Sub-word field packing requires an unsigned sized type and is only vaild inside a `struct`.
A by-value C union lowers to an explicitly-aligned byte blob with `bit_cast` accessors; a
union behind a pointer needs nothing beyond `declare struct` (§4).

```vertex
struct Sample001 {
  @bits(3) a: uint32
  @bits(5) b: uint32
}

@align(8) struct Sample002 {
  storage: array<byte, 8>
}
```

### Pointer Width
`usize` is 64-bit on `windows`, `linux`, and `darwin`, and **32-bit on `wasm`** (§5). Code
that treats `usize` and `uint64` as interchangeable is correct on three platforms and wrong
on the fourth.

---

## 4. Foreign Declarations — Shared Mechanics

Everything below — C, C++, Objective-C, and wasm imports — shares one grammar and five
rules.

**`declare struct`** introduces a layout-free type whose definition lives outside Vertex,
vaild only in pointer positions:

```vertex
declare struct Sample001
```

**`declare module` is both the declaration and the binder.** There's no separate import —
names marked `export` inside the block enter file scope directly:

```vertex
declare module "sample001" {
  export func sample002(n: uint32): int32
}
```

A declaration needed in more than one file goes in a Vertex module that holds the block:

```vertex
import "app/platform/libc"
```

**Trust, not verification.** The compiler never reads a header, class file, or framework
definition. A signature that disagrees with the real symbol fails at link time (bare
specifier), at instantiation (`wasm`), or at first use (`dynamic:`).

**Absence is always an explicit union.** C, C++, and Objective-C object pointers are all
nullable by default; Vertex bindings never are. `if let` is the ordinary unwrap:

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

**Failure is always a return union, never inferred.** C has no exceptions to infer from;
C++ and Objective-C both unwind, but Vertex doesn't, on any platform. A checked failure left
out of the union that fires anyway panics rather than silently dropping.

**Rest parameters** are call-shape, not a collection type. C varargs land in registers or
stack per the ABI; nothing inside an extern declaration can index, iterate, or take the
length of `args`.

```vertex
declare module "sample001" {
  export func sample002(fmt: const_ptr<byte>, ...args: CVarArg): int32
}
```

**Pointer parameters.** A `declare struct` is vaild only behind a pointer.

```vertex
declare module "sample001" {
  export func sample002(a: mutable_ptr<Sample001>): void
}
```

---

## 5. Platform Resolution

Four native platforms, three resolution stories.

| Platform | Specifier means | Bound at | Schemes |
|---|---|---|---|
| `windows` | library search path | link time | `dynamic:` |
| `linux` | library search path | link time | `dynamic:`, `cpp:` |
| `darwin` | library **or** framework path | link time | `framework:`, `dynamic:`, `cpp:` |
| `wasm` | import module name | instantiation | none |

### `windows` and `linux`: one resolver

One resolver each, so a bare specifier is unambiguous and needs no scheme.

```vertex
declare module "kernel32" { }     // windows, undecorated
declare module "c" { }            // linux, -lc
```

`"dynamic:libc"` opts into `dlopen`/`dlsym` resolution at first use instead of link time —
no link flag emitted, and the library need not exist at build time. It requires a userspace
OS loader, so it's unavailable under `nostd` and on `wasm`.

A dynamically-bound module fails in ways a linked one can't: the library may be absent, or
present without the symbol. Both surface at first use, not launch, as a panic — same tier as
a failed assertion.

### `darwin`: two resolvers

`darwin` has two genuinely different linker paths, so the specifier says which one directly.

```vertex
namespace yourlib
use darwin

declare module "System" {              // bare = library path, -lSystem
  func sample002(): int32
}

declare module "framework:WebKit" {    // framework path, -framework WebKit
  class Sample001 {
  }
}
```

The `.framework` extension is never spelled — `"framework:WebKit"`, never
`"framework:WebKit.framework"`. It's a filesystem detail the resolver appends.

**A library-resolved block may contain only flat function declarations** — a `class` inside
one is an error, since nothing about libSystem's resolution path produces Objective-C
runtime objects.

**A framework-resolved block may contain `class`/`interface`** (full Objective-C dispatch,
§6) **or C structs used at the boundary** (rects, points, sizes).

Mixing is disallowed by construction: one block resolves through exactly one path, so a
`class` and a library-only `func` need two blocks with two specifiers.

A framework-resolved block is what triggers the link (`-framework WebKit`); a framework with
no `declare module` block is not linked. Weak linking, framework search paths, and
deployment target are build configuration.

### `wasm`: an import namespace

Not a search path at all. The specifier is the import module name in wasm's two-level import
space; the embedder supplies the matching object at instantiation.

```vertex
namespace yourlib
use wasm

declare module "env" {
  export func sample001(a: int32): int32
}
```

A missing import fails at instantiation — earlier than `dynamic:` and later than a link
error, and reported by the embedder rather than by anything Vertex emits.

No schemes apply. There's no loader for `dynamic:`, no framework path, and no C++ mangling
target that a wasm module resolves through.

`nostd` is the ordinary case here: bare wasm has no syscalls, no filesystem, and no threads
unless the embedder grants them.

---

## 6. Objective-C / Darwin Interop

vaild only inside a `framework:`-resolved block (§5). Three things must match the real
framework exactly: **selector spelling**, **argument types**, and **nullability**.

### Foreign Ambient Class and Hierarchy
Declares a class whose definition, layout, and dispatch all live in the foreign runtime.
`extends` on one describes an existing hierarchy rather than creating it. Vertex-side classes
still can't extend anything except a foreign class.

```vertex
declare module "framework:WebKit" {
  class Sample001 {
    constructor()
  }
  class Sample002 extends Sample001 { }
}
```

### Static Methods, Protocols, Properties
Class methods (`+`) declare `static`; instance methods (`-`) declare bare. A protocol is an
`interface`; conformance is `implements`. `@property` maps to a field, `readonly` expresses
a readonly property.

```vertex
declare module "framework:WebKit" {
  class Sample001 {
    static sample002(): Sample001
    sample003(): void
  }
  interface Sample004 {
    sample005(a: Sample006): void
  }
  class Sample007 {
    readonly sample008: int32
    sample009: Sample010 | null
  }
}
```

### Nullable Access
`if let` unwraps and binds in one step; optional chaining remains available where the result
is discarded.

```vertex
if let a = Sample001.sample002(b) {
  a.sample003()
}
a?.b
```

### Selector Spelling: Three Forms

```vertex
a.sample001(b, { sample002: c })                    // labeled — ordinary spelling

class Sample001 {
  "sample002:sample003:"(a: int32, b: int32): void { }  // string-literal declaration
}

a["sample001:sample002:"](b, c)                      // literal selector call — last resort
```

### Blocks
An Objective-C block is an ordinary function type. Capture and lifetime are open (below).

```vertex
declare module "framework:WebKit" {
  class Sample001 {
    sample002(a: string, b: (c: Sample003 | null, d: Sample004 | null) => void): void
  }
}
```

### Error Out-Parameters
A trailing `NSError **` plus sentinel return becomes an ordinary return union — told, not
inferred.

```vertex
declare module "framework:WebKit" {
  class Sample001 {
    sample002(a: Sample003): Sample004 | null
  }
}
```

### Enums
`NS_ENUM` maps to the enum-with-underlying-type form. Case names are written as they appear
— no prefix stripping.

```vertex
enum Sample001: int64 {
  Sample001A = 0
  Sample001B = 1
}
```

### Naming
No heuristic renaming in either direction. The declared name is the program's name; the
selector is either derived by the labeled-call rule or written literally.

### Availability
Not spelled in source — a framework's OS version ranges live in a sidecar keyed by framework
name.

### Object Lifetime
Foreign objects are refcounted by the foreign runtime, not Vertex's inline header — bindings
behave as `shared_ptr<T>`: retain on copy, release at last reference. `unique_ptr<T>` isn't
available for them. Delegate-style back-references are the standard retain cycle — spell
them weak.

```vertex
let a: shared_ptr<Sample001> = Sample001()   // Managed-tier construction, not
                                             // make_shared — the allocation is the
                                             // foreign runtime's
let b: weak_ptr<Sample001> | null
```

### `@objc` Class Decorator
Marks a Vertex class dispatchable from the foreign runtime — the object gets a foreign
runtime header instead of Vertex's inline refcount header. `destructor` runs when the foreign
runtime releases the last reference; members reachable from the foreign runtime can't be
statically devirtualized; `implements` registers protocol conformance with the runtime.

```vertex
@objc class Sample001 implements Sample002 {
}
```

**Why this survives when `@android` didn't.** On `android` every class is a class file —
there was only ever one lowering, so a decorator marked the default and could be inferred
from the platform line. Here there are genuinely two: Vertex's inline refcount header, or the
foreign runtime's. Most classes in a darwin program want the first. The decorator picks, and
nothing in the platform line can pick for it.

---

## 7. C++ Interop

`"cpp:"` is a third scheme alongside bare and `dynamic:` — same family, same `declare module`
keyword, but it answers *how a name is spelled* at the ABI boundary rather than *when* it
resolves.

```vertex
declare module "cpp:mylib" {
}
```

### Mangling Is Platform-Owned
C++ has one mangled name per signature, and the scheme is ABI-specific — Itanium on
`linux`/`darwin`, MSVC decoration on `windows`. The compiler computes the mangled symbol from
namespace + class + signature per the active platform. A disagreeing signature fails at link
time.

```vertex
namespace yourlib
use linux

declare module "cpp:mylib" {
  export declare class Point {
    constructor(x: float64, y: float64)
    length(): float64
  }
}
```

### Namespaces Live in the Specifier
A C++ namespace rides in the specifier string. A block resolves through one library and one
namespace; mixing two namespaces needs two blocks.

```vertex
declare module "cpp:mylib" {                    // global namespace
  export declare class Sample001 { }
}

declare module "cpp:mylib::geometry" {           // mangled as geometry::Point
  export declare class Point {
    constructor(x: float64, y: float64)
  }
}
```

### Templates
C++ templates monomorphize, same as Vertex generics — no erasure or checked-cast tax at the
boundary. Vertex's own generic syntax is the binding.

```vertex
declare module "cpp:mylib" {
  export declare class Vector<T> {
    constructor()
    push_back(a: T): void
    size(): usize
  }
}
```

`Vector<int32>` at the call site is a real instantiation, mangled per that concrete `T`.

### References as Passing Modes
`mutating`/`readonly` (§1) are non-escaping borrows on the parameter's own terms — exactly
what a C++ `T&`/`const T&` is.

| C++ | Vertex |
|---|---|
| `T&` | `mutating T` |
| `const T&` | `readonly T` |
| `T*` | `mutable_ptr<T> \| null` |
| `const T*` | `const_ptr<T> \| null` |

References have no null state in C++, so they need no union; raw pointers stay
nullable-by-default like every other extern boundary.

### Object Lifetime: No Bridge Needed
`unique_ptr<T>`/`shared_ptr<T>` (§2) aren't an analogy to C++'s — modulo standard-library
implementation, they're the same layout. A bound C++ class is just a `class` with a real
destructor, run via the smart pointer's own teardown:

```vertex
var a: unique_ptr<Point> = make_unique<Point>(1.0, 2.0)
```

Writing `destructor` on a `declare class` here isn't vaild — the foreign one already runs via
the pointer's teardown.

### Overloads and Operators
Mangling encodes the full signature, so ordinary overloading declares without collision — no
descriptor-string form needed. Operators are the exception, since `operator+` isn't a vaild
Vertex identifier:

```vertex
declare module "cpp:mylib::geometry" {
  export declare class Vec2 {
    "operator+"(a: Vec2): Vec2
  }
}
```

```vertex
let c = a["operator+"](b)
```

### Exceptions and Virtual Dispatch
C++ unwinds; Vertex doesn't — a throwing method is a return union, told not inferred:

```vertex
declare module "cpp:mylib" {
  export declare class Parser {
    parse(a: string): Document | ParseError
  }
}
```

Foreign `virtual` methods dispatch dynamically at the call site; non-`virtual` ones
devirtualize — an explicit distinction, not inferred. `extends` on a foreign ambient class
describes an existing hierarchy.

---

## 8. Accelerated: Kernel and Graph Functions

vaild only in a file that names an accelerated backend (`cuda`, `msl`, `stablehlo`). No
backend line, no `kernel func`/`graph func` at all. Backends apply on `windows`, `linux`, and
`darwin`; none applies on `wasm`.

### Kernel Function
SIMT, side-effecting execution model. Lowers to PTX or MSL depending on the backend.

```vertex
kernel func sample001(): void {
}
```

### Graph Function
Pure dataflow model over whole tensors — no thread context. Lowers to a StableHLO string.

```vertex
graph func sample001(): tensor<float32, 1> {
}
```

### Exported Forms
Kernels are nameable to the compiler but not callable by host code — invoked only through
`compile`/`launch`. Graph functions are callable directly once compiled, no launch
configuration needed.

```vertex
export kernel func sample001(a: device_ptr<float32>, n: int32): void {
}

export graph func sample001(a: tensor<float32, 128, 64>): tensor<float32, 128, 64> {
  return a
}
```

### Device Pointer and Thread Context
`device_ptr<T>` and thread-context intrinsics are vaild only inside a `kernel func` body.

```vertex
let a: device_ptr<float32>

threadIdx.x
blockIdx.x
blockDim.x
gridDim.x
```

### SIMD and Tensor Types
`simd<T, N>` is trivially copyable, no modifier or file-level directive required.
`tensor<T, ...dims>` is shape-encoded and used exclusively in the graph route.

```vertex
let a: simd<float32, 4>
let b: tensor<float32, 128, 64>
```

### Compile and Launch
`compile` lowers a kernel or graph function into its target-specific compiled form; `launch`
invokes a compiled kernel with an explicit dimension configuration.

```vertex
let a = compile(sample001)
launch(config, a, b, c, n)
```