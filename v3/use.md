# use.md

## What `use` Is

`use <name>` states what a file expects of its target. Every line is optional; every line
present is a claim the build checks.

The default — no `use` line at all — is `int` vaild, no pointer family, no foreign
declarations, no OS or accelerator assumptions. This is deliberate: most real code is
business logic that never touches a foreign runtime, a raw pointer, or a GPU, and that code
should never have to know `use` exists.

```vertex
namespace yourspace

func add(x: int, d: int): int {
  return x + d
}
```

That file compiles under every target. It never made a claim, so there's nothing to check.

## Four Slots

| Slot | Values | Optional | Meaningful under |
|---|---|---|---|
| **Memory model** | `native`, `host` | yes — implied by platform | any platform but `any` |
| **Platform** | `any`, `windows`, `linux`, `darwin`, `wasm`, `android`, `js` | yes — absent means `any` | — |
| **Runtime** | `nostd`, `noentry` | yes | native platforms only |
| **Accelerated backend** | `cuda`, `msl`, `stablehlo` | yes | native platforms only |

Order is memory model, platform, runtime, backend. Stack only what you need.

```vertex
use android                      // platform only

use host
use android                      // memory model + platform — identical to the above

use native
use linux
use nostd
use noentry                      // + runtime — a kernel module

use linux
use cuda                         // + backend

use any                          // states portability explicitly
```

## Memory Model: Optional Because It's Implied

Two values, `native` and `host`. Each answers *who owns memory* — and each is already
determined by the platform, since no platform name appears under both.

| Memory model | Ownership | Pointer family | `destructor` | Implied by |
|---|---|---|---|---|
| `native` | ARC by default, manual available | full | vaild | `windows`, `linux`, `darwin`, `wasm` |
| `host` | host runtime's GC | absent (`weak_ptr`/`.lock()` survives under `android`) | invaild | `android`, `js` |
| *(none)* | — | absent | invaild | `any` |

So the line never changes what compiles. It exists for two reasons: a file can *say* what
it is rather than leave a reader to infer it, and the type system's two independent
questions — who owns memory, what the numerics are — each get a place to be written.

Write both lines when ownership matters to whoever reads the file next; a file full of
`weak_ptr` and hand-written teardown earns a `use host` at the top. Write the platform
alone for ordinary code. Pick one convention per codebase and let a lint hold it — the
compiler accepts either.

**A memory model line alone is an error.** `use host` with no platform names no numeric
table, so there's nothing to check the file's types against.

**A memory model line that disagrees with its platform is an error.** `use host` above
`use windows` doesn't select anything; it contradicts something already known.

**No memory model line is vaild above `use any`.** An Any file never allocates in a way
that distinguishes ARC from a host GC.

## Platform: Fixes the Types and the Resolver

Platform is the load-bearing line. It fixes the numeric table and decides how a bare
`declare module` specifier resolves. Full type tables are in platforms.md; what follows is
the resolution rule for each.

### `any`

No foreign declarations at all. Nothing to resolve.

`use any` is optional in the same way the memory model line is — a file with no `use` line
is checked against exactly this table. Writing it turns an absence into a statement, since
an empty header is ambiguous between "deliberately portable" and "nobody thought about it."

Its check always passes. The claim is "this file asserts no target-specific types," which
is true under every target, so `use any` is the one platform line that cannot error on
target grounds.

### `windows`, `linux`

One resolver each — the library search path — so a bare specifier is unambiguous and no
scheme is needed.

```vertex
namespace yourlib
use windows

declare module "kernel32" {          // undecorated
}
```

```vertex
namespace yourlib
use linux

declare module "c" {                 // -lc
}
```

**`dynamic:`** opts a specifier into `dlopen`/`dlsym` resolution at first use instead of
link time. A dynamic loader is a userspace OS service, so this is meaningful only where one
exists — excluded under `nostd`, and unavailable on `wasm`.

```vertex
namespace yourlib
use linux

declare module "dynamic:c" {
}
```

### `darwin`: two resolvers, not one

`darwin` is the one platform where a bare specifier is genuinely ambiguous — libSystem and
a framework resolve through different linker paths (library search path vs. framework
search path). Rather than inferring the resolver from what's inside the block, the
specifier says so directly, using the same scheme-prefix family as `dynamic:`.

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

The specifier is bare — `"framework:WebKit"`, never `"framework:WebKit.framework"`. The
`.framework` extension is a filesystem detail the resolver appends; spelling it in source
would double it at link time and reads as a path rather than a scheme + name pair. The
prefix form also does work a suffix wouldn't: it tells the reader which resolver is in play
before they've read a single member of the block.

A library-resolved block may contain only flat function declarations — a `class` inside one
is an error, not an inference trigger, since nothing about libSystem's resolution path
produces Objective-C runtime objects. A framework-resolved block may contain
`class`/`interface` (Objective-C dispatch) or C structs used at the boundary (rects,
points, sizes are ordinary `struct` and never go through the scheme).

**Mixing is disallowed by construction, not by a rule to remember**: a single
`declare module` block resolves through exactly one path, so a `class` and a library-only
`func` can never vaildly coexist in one block. They need two blocks with two specifiers,
which is also the honest description of what happens at the linker.

### `wasm`

Not a library search path — a two-level import namespace. The specifier is the import
module name; the embedder supplies the matching object at instantiation, and a missing
import fails there rather than at first use.

```vertex
namespace yourlib
use native
use wasm

declare module "env" {
  export func sample001(a: int32): int32
}
```

No `dynamic:` — core wasm has no loader to ask.

`nostd` is the ordinary case here, not the exception: bare wasm has no syscalls, no
filesystem, and no threads unless the embedder grants them.

### `android`

Foreign names arrive by package through the classpath. `android.widget`, `android.app`,
`java.util`, and any Kotlin or server-JVM package are the same mechanism.

```vertex
namespace yourlib
use android

declare module "android.widget" {
  export declare class Sample001 {
    constructor()
    sample002(a: int32): void
  }
}
```

Resolution is by name at first use; a missing class or member panics. Classpath composition
— `android.jar` versus a JDK, API level, minSdk — is build configuration. The platform line
never carries a version, and the grammar couldn't spell one anyway: `UseDirective: use
Identifier` takes no arguments.

### `js`

The specifier is handed to the host resolver — webpack, esbuild, Node's own resolution —
unchanged. A bare package name, a relative path, and a built-in module name are all just
strings Vertex doesn't interpret.

```vertex
namespace yourlib
use js

declare module "websocket" {
  export declare class Sample001 {
    constructor(a: string)
    send(a: string): void
  }
}
```

Exactly one resolver, so no scheme prefix exists — there's nothing to disambiguate. A
missing module is the host bundler's error.

## Runtime: `nostd` / `noentry`

Two prior-art models exist for the "no OS underneath" case, and they disagree on
granularity in a way worth resolving deliberately rather than picking one by default.

**C++** draws one line — hosted vs. freestanding. Freestanding means a much smaller library
surface (containers needing exceptions or heap, such as `vector`/`list`/`deque`/`map`, are
never available), possibly-unavailable threading, and an implementation-defined entry point
where hosted requires a global `main()`. One flag, entry-point behavior bundled in as a
consequence of the same flag.

**Rust** draws two lines — `#![no_std]` (no standard runtime, no heap or OS assumptions)
and `#![no_main]` (no default entry point, the build supplies its own, conventionally
`_start`), kept explicitly independent because a `no_std` program can still run under
something that calls a conventional entry point — a bootloader or RTOS sitting underneath
it.

Vertex follows Rust's split rather than C++'s bundle, since platform and backend are
already independent slots here — collapsing runtime into one flag would be the odd one out.

- **`nostd`** — no standard runtime assumed. No heap-backed containers: `vector<T>` and
  anything depending on `block<T>`'s heap allocation become invaild or conditional, same
  reasoning C++ excludes `vector`/`list`/`deque`/`map` from freestanding. No OS-service
  assumptions, so `dynamic:` resolution is unavailable — there's no userspace loader to
  ask. Primitive operations that would otherwise reach for SIMD/FP registers may need to
  avoid them until CPU state is known-initialized, matching why kernel-flavored `memcpy`
  implementations in C++ freestanding code avoid vector registers. A `nostd` file can still
  declare an ordinary `func main(): int32` if something downstream calls it — exactly the
  case Rust's split exists to preserve.
- **`noentry`** — no default entry point. The build supplies its own symbol (conventionally
  `_start`, matching both Rust's and C++'s freestanding convention) instead of `main` being
  called for it. vaild only alongside `nostd` — a program with a runtime under it has no
  reason to reject that runtime's entry sequence.

```vertex
use linux
use nostd                       // heap/OS-free, but something still calls main()

use native
use nostd
use noentry                     // supplies its own _start — a kernel module

use native
use nostd
use noentry                     // one layer lower — a bootloader
```

A kernel module and a bootloader are both `nostd + noentry`; neither needs its own name,
and both inherit `native`'s pointer and sizing rules unchanged. Runtime only strips away
what depended on a hosted OS.

Note the second and third examples name no platform, which is vaild — a freestanding target
that isn't `windows`/`linux`/`darwin` has no linker convention to pick. But a memory model
line alone is an error, so `use native` is required there rather than optional; it's the
only line left to hang the runtime slot on.

Neither `nostd` nor `noentry` is meaningful under `android` or `js` — both already abstract
the OS away, and there's nothing for the line to strip.

## Accelerated Backend: Gates Kernel/Graph Bodies

`kernel func` and `graph func` bodies are vaild only in a file that names a backend, and
the backend decides which intrinsics resolve inside them.

```vertex
namespace yourlib
use linux
use cuda

kernel func add(): void {
  // cuda-family intrinsics only — threadIdx.x and friends
}
```

```vertex
namespace yourlib
use darwin
use msl

kernel func add(): void {
  // MSL-family thread-position intrinsics only
}
```

```vertex
namespace yourlib
use linux
use stablehlo

graph func add(): tensor<float32, 1> {
  // pure dataflow, no thread context, lowers to a StableHLO string
}
```

A file with no backend line cannot declare `kernel func` / `graph func` at all — this is
what turns thread-context intrinsics on.

`stablehlo` is the odd one out: `graph func` has no thread context and lowers to a string
artifact rather than machine code, so whether the platform line does anything for it is
genuinely open — don't assume `use linux` is load-bearing there until confirmed.

No backend applies under `android`, `js`, or `wasm`.

## Compiler Behavior

Two shapes, driven by whether the file made any claim at all.

**1. No `use` line.** Target-agnostic. Compiles under any build, rides along under whatever
profile the build resolves, and never errors on target grounds — it never made a claim to
check.

**2. Any `use` line present.** The build must already have a resolved target, or the file
cannot compile. This is stronger than "wrong target" — it's "nothing to compare against
yet." Once the build has one, each line is checked independently:

- Line matches the build → passes.
- Line contradicts the build → errors.

A `use windows` file in a `linux` build errors the same way a `use android` file in a
`native` build does.

Three additional errors are internal to the file, checkable before the build's target is
known:

- A memory model line with no platform line.
- A memory model line contradicting its platform's implied model.
- `use noentry` without `use nostd` — independent slots, but not independently satisfiable.

`use any` is the sole line that always passes step 2, on every target.