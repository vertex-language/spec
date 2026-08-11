# platforms.md

## What This Covers

Vertex's grammar — `if`/`else`/`while`/`for`/`func`/`class`/`struct`/control flow — is
identical everywhere. What changes per target is which **types** are vaild, and how a
foreign specifier resolves. Nothing here changes syntax — only which types resolve.

A target is named by a **platform line**, optionally preceded by a **memory model line**:

```vertex
use host       use host       use native     use native     use native     use native
use android    use js         use windows    use linux      use darwin     use wasm
```

The platform line is the one that does the work. It fixes the numeric table and the
resolver, and every platform name is unique across the whole set — `android` is only ever
host-owned, `windows` is only ever manual. So the memory model is already determined by
the time you've read the second line.

**The memory model line is optional, for the same reason `use any` is optional: it states
something the compiler already knows.** Both exist so a file can *say* what it is rather
than have it inferred, and so the type system's two independent questions — who owns
memory, what the numerics are — each have a place to be written. Neither line changes what
compiles.

```vertex
use android       // complete on its own — host ownership is implied
```

```vertex
use host
use android       // identical, and says so
```

Write both when a file's ownership model matters to whoever reads it next — a file full of
`weak_ptr` and hand-written teardown benefits from `use host` at the top. Write the
platform alone for ordinary code. Pick one convention per codebase and let a lint hold it;
the compiler accepts either.

---

## Memory Model — Optional First Line

### `use native`

You manage memory yourself. The full pointer family, manual allocation, layout control,
`destructor`, and foreign interop.

```vertex
let a: shared_ptr<Sample001>
let b: unique_ptr<Sample001>
let c: weak_ptr<Sample001>

let d: mutable_ptr<Sample001>
let e: const_ptr<Sample001>
let f: void_ptr

var g = make_unique<Sample001>(0, 0)
var h = make_shared<Sample001>(0, 0)
```

Ordinary construction is still ARC'd — `var a = Sample001()` allocates and refcounts
invisibly. Native is *optionally* manual, not unmanaged; the two tiers coexist (native.md
§2).

`destructor` is vaild and deterministic.

Implied by `windows`, `linux`, `darwin`, `wasm`.

### `use host`

A host runtime owns memory. No pointer family, no manual allocation, no layout control,
no `destructor`.

`destructor` is invaild under `host` on both platforms, and for the same reason on both:
teardown in Vertex is deterministic and scope-bound, while ART's `Cleaner` and JS's
`FinalizationRegistry` both run at an unspecified time relative to collection. Cleanup for
foreign resources is written by hand on every exit path.

The pointer family is absent, with one platform-specific survivor — `weak_ptr`/`.lock()`
under `android`, for the live-root case a tracing GC can't see past (a long-lived callback
or background thread holding `this`). It is not a memory-model feature; it exists because
one platform's GC has a shape that needs it.

Implied by `android`, `js`.

### No line for `any`

`use any` names no memory model, because an Any file never allocates in a way that
distinguishes ARC from a host GC. There is no vaild first line for it.

---

## Platform — The Required Line

Platform fixes two things: the **numeric table**, and how a bare `declare module`
specifier resolves.

| | `android` | `js` | `windows` | `linux` | `darwin` | `wasm` |
|---|---|---|---|---|---|---|
| Implies | `host` | `host` | `native` | `native` | `native` | `native` |
| `int` | boundary-restricted¹ | only numeric | vaild | vaild | vaild | vaild |
| Sized numerics | mandatory | invaild | vaild | vaild | vaild | vaild |
| `struct` | see §Open | yes | yes | yes | yes | yes |
| `weak_ptr` | yes | no | full family | full family | full family | full family |
| Foreign surface | classpath | host bundler | library path | library path | library + framework | import namespace |

¹ Unresolved — see *Open Questions*.

### `android`

Sized types are exact because descriptors are exact. No unsigned types — `uint8`…`uint64`
lower to same-width signed primitives with reinterpreted operations. `usize` is `long`.
`bool` is `boolean`.

```vertex
int8
int16
int32
int64
uint8
uint16
uint32
uint64
usize
float32
float64
bool
```

```vertex
var strong: Sample001 = Sample001()
var weak: weak_ptr<Sample001> = weak_ptr(strong)

if let live = weak.lock() {
  live.doSomething()
}
```

Foreign names arrive by package through the classpath. `android.widget`, `android.app`,
`java.util`, and any Kotlin or server-JVM package are all the same mechanism — a package
name in a `declare module` specifier.

```vertex
declare module "android.widget" {
  export declare class Sample001 {
    constructor()
    sample002(a: int32): void
  }
}
```

Resolution is by name at first use; a missing class or member panics
(`NoClassDefFoundError` / `NoSuchMethodError`). Classpath composition — `android.jar`
versus a JDK, API level, minSdk — is build configuration, not language. The platform line
never carries a version.

### `js`

`int` only. Every sized type is invaild, because a JS engine has exactly one numeric
representation (`number`, IEEE-754 double) for anything not explicitly boxed as `BigInt`.
An unsized type is always correct there; a sized one would assert a width the runtime
doesn't distinguish. `bool` is `boolean`.

```vertex
int
string
bool
```

`js` names the ECMA-262 value model, not a specific runtime — browser, Node, Deno,
workers, and embedded engines all present the same one. Which of those you're on is build
configuration.

Foreign names arrive by module specifier, handed to whatever the host resolver is
(webpack, esbuild, Node's own resolution) unchanged. No scheme prefix exists — there's
exactly one resolver, so there's nothing to disambiguate.

```vertex
declare module "websocket" {
  export declare class Sample001 {
    constructor(a: string)
    send(a: string): void
  }
}
```

### `windows`, `linux`, `darwin`

All three share one numeric table — `int` plus the full sized set. Types are identical on
all three; the platform line picks a **linker convention**, nothing else.

```vertex
int
int8
int16
int32
int64
uint8
uint16
uint32
uint64
usize
float32
float64
byte      // alias for uint8
```

`windows` and `linux` have exactly one resolver each (library search path), so a bare
specifier is unambiguous:

```vertex
declare module "kernel32" { }     // windows, undecorated
declare module "c" { }            // linux, -lc
```

`darwin` has two genuinely different linker paths, so the specifier says which:

```vertex
declare module "System" {              // bare = library path, -lSystem
  func sample002(): int32
}

declare module "framework:WebKit" {    // framework path, -framework WebKit
  class Sample001 { }
}
```

A library-resolved block may contain only flat function declarations; a framework-resolved
block may contain `class`/`interface` or boundary C structs. Full rules in native.md §5–6.

### `wasm`

Linear memory, allocated and freed by the program. The full pointer family, manual
allocation, layout control, and `destructor` all apply unchanged — a raw pointer is an
offset into linear memory, and `addressof`, `offset`, `align_up`, `bit_cast`, and
`unaligned_load` all mean what they mean on any other native platform.

```vertex
use native
use wasm

var a: block<int32> = alloc<int32>(usize(256))
var b: mutable_ptr<int32> = a.data()
b.offset(4)[0] = 1
```

Wasm is under `native` because the memory model *is* native. The embedder hands you a
region of bytes; it does not track what's live inside it. An out-of-bounds access traps and
ends the instance, but a stray write inside your own heap corrupts silently — the same
bargain `linux` offers. It also matches intent: the reason to reach for wasm at all is
control over layout and allocation, and the target line should say so before the first line
of code.

**`usize` is 32-bit** under wasm32 — the one place in the native family where pointer width
isn't 64. Code that assumes `usize` and `uint64` interchange is wrong here and correct on
the other three. wasm64 is not a separate platform line; it's build configuration, the same
way `linux` doesn't spell x86-64 versus aarch64.

**Foreign resolution is a two-level import namespace,** not a library search path. The
specifier is the import module name; the embedder supplies the matching object at
instantiation, and a missing import fails there rather than at first use.

```vertex
declare module "env" {
  export func sample001(a: int32): int32
}
```

There is no `dynamic:` under `wasm` — core wasm has no loader to ask, the same reason
`nostd` excludes it.

**`nostd` is the common case,** not the exception. Bare wasm has no syscalls, no
filesystem, no threads unless the embedder grants them. A wasm module that expects a hosted
runtime is asserting something about the embedder that the platform line can't check.

```vertex
use native
use wasm
use nostd
```

### `any`

The plain-types table: `int`, `string`, `bool`, `class`, `struct`. No sized numerics, no
pointer family, no manual memory, no foreign declarations.

That restriction *is* the portability. Every platform can express `int`, `string`, and
`bool`; none can express another's additions. Any is the intersection, so an Any file
compiles under every target unchanged.

```vertex
namespace yourspace

use any

func add(x: int, d: int): int {
  return x + d
}
```

**`use any` is itself optional.** A file with no `use` line at all is checked against
exactly this table and behaves identically. Same reasoning as the memory model line:
written so portability can be *stated* rather than inferred from an absence, since an empty
header is ambiguous between "deliberately portable" and "nobody thought about it."

**`use any` never conflicts with a build.** Its check always passes — the claim is "this
file asserts no target-specific types," true under every target. It's the one platform line
that cannot error on target grounds.

---

## Slot Rules

Every line is checked; none is required.

- **Platform line.** Optional. Absent, the file is checked as `any`. Present, it must match
  the build's platform.
- **Memory model line.** Optional. vaild only where it agrees with the platform's implied
  model. `use host` above `use windows` is an error, as is any memory model line above
  `use any`.
- **A memory model line alone** — `use host` with no platform — is an error. It doesn't
  name a numeric table, so there's nothing to check a file's types against.

Two further slots exist under the native platforms only, both optional:

- **Runtime** — `nostd`, `noentry`. Strips the userspace-OS assumption. `noentry` requires
  `nostd`.
- **Accelerated backend** — `cuda`, `msl`, `stablehlo`. Gates `kernel func` / `graph func`
  bodies.

```vertex
use linux
use nostd
use noentry     // a kernel module

use linux
use cuda        // gates kernel func
```

Neither is meaningful under `android` or `js` — a host runtime already abstracts the OS
away and has no accelerated route. Either one there is an error. Under `wasm`, `nostd` is
the ordinary case and no accelerated backend applies.

---

## Summary

| Platform | Implies | Numerics | struct | Pointer family | Foreign |
|---|---|---|---|---|---|
| `any` *(or no line)* | — | `int` only | yes | no | no |
| `android` | `host` | sized only | see §Open | `weak_ptr` only | classpath packages |
| `js` | `host` | `int` only | yes | no | host bundler modules |
| `windows` | `native` | `int` + full sized | yes | full | library path |
| `linux` | `native` | `int` + full sized | yes | full | library path, `dynamic:` |
| `darwin` | `native` | `int` + full sized | yes | full | library + `framework:` |
| `wasm` | `native` | `int` + full sized | yes | full | import namespace, no `dynamic:` |

One grammar, seven platforms, three memory models — two of which are spellable and all
three of which are implied. Any is the intersection; each of the others adds along a
different axis: the native platforms add machine access, `android` adds exact widths, `js`
adds foreign reach without adding types.

Note that `js` and `wasm` are both browser-reachable and land on opposite ends of the
table. That's correct, and it's the clearest statement of what the two lines are for: same
delivery vehicle, opposite answers to who owns memory.