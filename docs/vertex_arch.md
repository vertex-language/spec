# Vertex IR Architecture
## Design, Trade-offs, and the Road Not Taken

---

## Overview

Vertex compiles through three fully independent pipelines — ir/c, ir/objc,
and ir/cpp — that meet only at the linker. This document explains why that
architecture exists, what it cost to build it, what it gives back, and what
the realistic alternatives were and why they were set aside.

---

## The Core Problem

A systems language that wants to be useful across the full stack faces a
fundamental tension:

**Low-level targets** (kernels, bootloaders, bare metal firmware) need a base
with no runtime overhead — no vtables firing before entry, no ARC reference
counts, no static constructors, no exception unwind tables in a binary that
runs before an OS exists.

**High-level targets** (macOS UI, Windows graphics, GPU compute) require
access to platform runtimes that are built in Objective-C and C++. UIKit,
MetalKit, Direct3D, CUDA — these are not C libraries. You cannot reach them
through a C boundary alone without losing the type contracts that make them
usable.

The naive resolution is to pick a side. Most languages do. Vertex does not.

---

## The Resolution: Parallel Pipelines, C as the True Base

ir/c is the base of the language. It has no runtime. It makes no assumptions
about the target environment. A Vertex source file that imports nothing
platform-specific compiles through ir/c → ir/mir → encoder and produces an
object file that can be linked into a bootloader, a kernel module, or a
POSIX application equally.

ir/objc and ir/cpp are not layers on top of ir/c. They are parallel pipelines,
activated only when a Native Interface for that language is imported. They own
their full path from frontend to object file and carry their respective runtimes
only into the targets that need them.

```
ir/c        →  bare metal, kernels, POSIX, normal application code
ir/objc     →  UIKit, AppKit, MetalKit, Foundation, GCD
ir/cpp      →  Direct3D, Vulkan (C++ surface), CUDA host side, COM
```

The three pipelines meet at the linker. Nothing else is shared.

---

## Native Interfaces

A Native Interface is a bridge package file. It declares foreign class
signatures as Vertex types and is the single source of truth the compiler
uses to understand what lives on the other side of a language boundary.

```swift
/* uikit.vs — Native Interface for UIKit */
package uikit
build darwin
import "darwin/objc/uikit"

class UILabel : UIView {
    func setText(self: UILabel, text: string)
    func setTextColor(self: UILabel, color: UIColor)
}
```

These files live in the standard library or a package repository. The
developer never opens them or writes them for standard platform SDKs.

When a call site in Vertex source meets a foreign type declared in a Native
Interface, the compiler generates ir/c bindings — glue code that forms the
concrete connection between pipelines. The bindings are compiled through the
ir/c path and linked alongside the other object files.

The developer writes:

```swift
label.setText("hello world")
```

The compiler generates the NSString conversion, the objc_msgSend dispatch,
and the correct selector. None of it is visible at the call site.

---

## Why "Compile to Real .objc and .cpp" Matters

The ir/objc pipeline does not interpret or emulate Objective-C semantics.
It emits real Objective-C IR — real msgSend dispatch, real ARC retain/release,
real block structs, real metadata sections. The ir/cpp pipeline emits real
C++ vtable layouts, real Itanium or MSVC name mangling, real .eh_frame records.

This means the correctness of those runtimes is inherited, not reimplemented.
ARC is not approximated. Vtable layout is not guessed. Exception unwinding
is not hand-rolled. The compiler generates the genuine artifact and the
platform runtime handles the rest.

This is a large amount of work that does not have to be done.

---

## Trade-offs Made

### What was accepted

**Three codebases instead of one.**
ir/c, ir/objc, and ir/cpp are maintained independently. Each has its own
MIR layer and its own encoder path. There is no shared node tree to simplify
lowering. Cross-pipeline concerns — the generated ir/c bindings — require
the compiler to read and synthesise across all active Native Interfaces at
build time.

**The Native Interface surface must be written and maintained.**
Standard platform SDK Native Interfaces ship in the standard library and are
stable across SDK versions. But any new platform or third-party library
requires a Native Interface to be authored. This is a one-time cost per
library, not per use site, but it is a real cost.

**CUDA is not as clean as the rest.**
CUDA is an nvcc C++ extension with device/host function annotations
(`__global__`, `__device__`), kernel launch syntax (`<<<grid, block>>>`),
and unified memory semantics that live outside standard C++. The ir/cpp
pipeline covers the host side. The device side and launch syntax require
their own Native Interface treatment and likely a specialised extension to
mir/cpp. It is not a blocker, but it is not as clean as D3D11 or UIKit.

**"Apple Metal" requires careful naming discipline in documentation.**
Apple Metal (the GPU API, accessed through MetalKit via ObjC) and bare metal
(the compilation target) share a name in common usage. The ir/objc pipeline
handles Apple Metal correctly. The distinction must be explicit in all
documentation to avoid confusion.

### What was gained

**The full stack is reachable from one language.**
The same language writes a bootloader, a kernel driver, a macOS UI with
UIKit, a Direct3D renderer, and a POSIX daemon. Most languages surrender one
end of this range to get the rest.

**Low-level targets pay zero runtime cost.**
A bare metal target activates no ObjC runtime, no C++ runtime, no ARC, no
exception tables. ir/c generates a clean object file with no implicit
overhead.

**High-level targets inherit full runtime correctness.**
UIKit, AppKit, COM, and Direct3D behave exactly as they do in native ObjC
and C++ code. Memory management, dispatch, and ABI are handled by the
platform runtimes, not by Vertex.

**Linker flags are automatic.**
Active Native Interface declarations determine which runtime libraries the
linker needs. `-lobjc -framework UIKit` or `d3d11.lib` are emitted with the
generated bindings. The developer does not write linker flags.

---

## The Road Not Taken

### Option 1: C++ as the base

The most common choice for a new systems language targeting both C and C++
ecosystems. Rust, Swift (partially), and several experimental languages have
taken this route.

**What it would give:**
Direct access to the C++ standard library and the full C++ ABI from all
code paths. CUDA host-side integration would be simpler. The compiler would
not need a separate ir/cpp pipeline — C++ semantics would be native.

**What it would cost:**
The C++ runtime would be present in every binary. Static constructors, vtable
overhead, and the C++ ABI would be baseline assumptions even for a
bootloader. Writing a kernel module would require either a separate stripped
build mode (adding complexity) or accepting that the language is not suitable
for bare metal. The low end of the stack — firmware, bootloaders, bare metal
RTOS targets — would effectively be closed off or require a separate
dialect.

The ObjC story would also be harder. C++ and ObjC are separate runtimes with
separate ABIs even on Darwin. A C++ base does not simplify ObjC interop;
it makes the ir/objc pipeline equally necessary while loading the base with
C++ runtime cost regardless.

**Why it was set aside:**
The language explicitly targets bare metal compilation as a first-class
concern. A C++ base forecloses that without significant mitigation work, and
the mitigation (a `no_runtime` mode or a separate kernel dialect) adds
complexity without recovering the clean separation that the parallel pipeline
architecture gives for free.

---

### Option 2: A Single Unified IR (LLVM-style)

Design a single IR that can represent ObjC, C++, and C constructs uniformly
and lower them through one pipeline.

**What it would give:**
One codebase to maintain. Cross-language optimisations across the IR boundary.
Simpler compiler architecture at the IR level.

**What it would cost:**
LLVM itself took this approach and the result is an IR that represents ObjC
and C++ adequately but at the cost of significant complexity in the IR
design. ObjC ARC semantics, block structs, and msgSend dispatch variants do
not map cleanly onto C++ constructs and vice versa. A unified IR that handles
both correctly either becomes very large or elides important semantics that
must be recovered at lowering time.

More importantly: taking a dependency on LLVM or building an LLVM-equivalent
unified IR is a multi-year project that would defer everything else. The
parallel pipeline architecture lets each pipeline be as correct and focused
as it needs to be without one pipeline's requirements contaminating another.

**Why it was set aside:**
The complexity budget for a unified IR that genuinely handles all three
language families correctly is very high. The parallel pipeline architecture
pays a maintenance cost (three codebases) but each codebase is focused and
independently auditable. The unified IR approach trades that maintenance cost
for design complexity that is harder to isolate and reason about.

---

### Option 3: Transpilation to C, ObjC, or C++

Compile Vertex source to C (or ObjC/C++) source, then hand off to a host
compiler (clang, gcc, MSVC).

**What it would give:**
Zero encoder work. The host compiler handles optimisation, ABI, and object
file generation. Broad platform support for free.

**What it would cost:**
Transpilation to C loses type information that the host compiler cannot
recover. Error messages point into generated C, not Vertex source. Debugging
is painful. Round-tripping through a host compiler's optimiser means Vertex
has no control over codegen quality or binary layout — unacceptable for
bare metal or kernel targets where section layout and calling convention
control are requirements.

ObjC transpilation specifically: clang is the only widely available ObjC
compiler. Depending on clang for correctness means depending on clang's
continued maintenance of ObjC ARC, which is not guaranteed long-term given
Apple's direction toward Swift.

**Why it was set aside:**
Transpilation is appropriate for bootstrapping or for high-level languages
that do not require precise binary output. Vertex requires precise binary
output. The transpilation path closes off bare metal targets and yields
control of codegen to a host compiler. The parallel pipeline architecture
retains full control at the cost of more implementation work — a cost that
is worth paying.

---

### Option 4: Runtime FFI Bridge (Swift-style @objc)

Expose foreign types through a runtime reflection and bridging layer rather
than a compile-time Native Interface and generated bindings.

**What it would give:**
More dynamic interop. The ability to call ObjC methods discovered at runtime
without a Native Interface declaration.

**What it would cost:**
Runtime FFI bridges carry overhead per call. They require runtime type
metadata to be present in both the calling and called runtimes. They are
incompatible with bare metal targets where no runtime exists. And they make
it impossible for the compiler to generate type-safe bindings — the
developer either writes annotations (equivalent effort to a Native Interface)
or loses type safety at the boundary.

Swift's `@objc` bridge is effective within the Swift/Darwin ecosystem but
is inseparable from the Swift runtime, ARC, and the assumption of a running
OS. Vertex cannot carry those assumptions.

**Why it was set aside:**
The compile-time Native Interface approach generates bindings once, catches
type errors at compile time, and produces zero-overhead call sites. A runtime
FFI bridge trades type safety and bare metal compatibility for dynamism that
Vertex does not need. The Native Interface system covers the full static
interop surface of any platform SDK.

---

### Option 5: Build on an Existing IR (QBE, GCC GIMPLE)

Use QBE or GCC GIMPLE as the backend IR rather than building ir/mir from
scratch.

**What it would give:**
A maintained optimisation pipeline. Existing register allocators, instruction
selectors, and target backends. Significantly less implementation work at
the backend level.

**What it would cost:**
QBE is deliberately simple and does not support the full set of calling
conventions and ABI concerns required for ObjC (stret variants, ARC
intrinsics) and C++ (Itanium EH tables, MSVC mangling). GIMPLE carries the
full weight of the GCC architecture and the GPL, making it unsuitable for
a cleanly licensed, independently maintained compiler.

Both options would require forking or patching the backend IR to handle the
ObjC and C++ lowering requirements, at which point the independence of the
modification is largely lost.

**Why it was set aside:**
The mir/objc and mir/cpp layers have requirements specific enough that a
general-purpose backend IR would need to be extended substantially. Building
ir/mir directly gives full control over the lowering decisions that matter
for platform correctness — stret selection, ARC injection sites, block
struct layout — without negotiating with an upstream project's design
constraints.

---

## Summary

| Decision | Alternative | Why parallel pipelines won |
|---|---|---|
| ir/c as true base | C++ as base | Bare metal and kernel targets require a runtime-free foundation |
| Parallel pipelines | Unified IR | Focused correctness per pipeline vs. unified complexity |
| Compile-time Native Interface | Runtime FFI bridge | Type safety, zero overhead, bare metal compatible |
| Generated ir/c bindings | Transpilation | Retain codegen control, correct error attribution |
| ir/mir built in-house | QBE / GIMPLE | ObjC and C++ lowering requirements exceed what general IRs provide |

The architecture accepts a higher implementation cost — three pipelines, three
MIR layers, a binding generator, a Native Interface system — in exchange for
a language that reaches from a 16-byte bootloader entry point to a full
UIKit application without a mode switch, a dialect boundary, or a runtime
the target does not want.

That range was the requirement. The architecture follows from it.