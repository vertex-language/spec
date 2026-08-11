# arch_v2.md

## The Core Vision: One Grammar, Two Memory Models

The historical failure of modern languages is the FFI cliff. Developers write business logic in a safe, managed language, but the moment they need to touch the metal, optimize a hot path, or talk to the OS, they are forced to jump into C++ or Rust. This splits codebases, build systems, and development teams.

Vertex solves this by maintaining a strict, unchanging grammar across two distinct memory tiers. You do not change languages to write a GPU kernel or a native OS hook; you simply change the tier.

---

## Tier 1: Managed (The Default)

**Execution Model:** Automatic Reference Counting (ARC) for native; Host GC for foreign targets.
**Use Case:** 90% of standard application code, UI, and business logic.
**Targets:**
- `native` (Windows, Linux, macOS machine code using compiler-inserted ref counting)
- `jvm` (Android apps, lowering to classfile bytecode and leaning on the JVM's host GC)
- `js` (Browser bundles, leaning on V8's host GC)

**The Python Reference:**
Like CPython, Vertex's native Managed tier is overwhelmingly driven by immediate reference counting, not a heavy, stop-the-world tracing GC. When a reference count hits zero, the object is instantly deallocated. However, where Python requires a background cyclic GC to clean up circular references, Vertex relies on strict static typing: developers use `weak_ptr` to break cycles structurally.

**The Developer Experience:**
Safe, simple, and high-velocity. In the Managed tier, manual pointer management is completely locked away. Memory is handled invisibly by the compiler. The developer writes pure structural logic using `class`, `struct`, and `interface` without worrying about allocation lifecycles or teardown.

---

## Tier 2: Unmanaged (The Metal)

**Execution Model:** Deterministic, zero-magic, manual pointer control.
**Use Case:** Hot paths, OS integrations, GPU kernels, and embedded systems.
**Targets:**
- `native` (opting out of ARC for raw manual control)
- Accelerated routes via `use metal`, `use cuda`, or `use freestanding`

**The Developer Experience:**
An explicit opt-out of the managed runtime. This tier unlocks the pointer family. Ownership is handled deterministically via manual ref-counting (`shared_ptr`, `weak_ptr`) and single-ownership (`unique_ptr`). It provides raw memory access, exact struct layout control, and predictable teardown, delivering C++ performance natively.

---

## The Boundary: Mixing Tiers

The true superpower of Vertex is that **Managed code can call Unmanaged code natively, without leaving the language.**

Because the native Managed tier relies on ARC rather than a tracing GC, the memory substrates match perfectly. A compiler-inserted retain in Managed code and a manual `shared_ptr` retain in Unmanaged code speak the exact same ABI language. The compiler just increments the integer ref-count and hands the pointer across the boundary without pinning memory or JNI translation.

### Acknowledging the Constraints

Because these are two fundamentally different hardware realities, Vertex enforces strict boundaries to prevent the Managed tier from corrupting the Unmanaged tier, and vice versa:

1. **Cycle Breaking is Manual:** Highly dynamic GC behavior does not exist on native targets. Managed code relies on strict `weak_ptr` discipline to break cycles, ensuring memory never leaks.
2. **Metal Concepts Don't Flow Up:** You cannot pass a raw `mutable_ptr` or `device_ptr` up into the Managed tier. The boundary requires exchanging clean value types (`struct`), scalar primitives, or specifically opaque bridged references.
3. **No Mixed-Tier Inheritance:** A managed class cannot inherit from an Unmanaged ref-counted class. Polymorphism across the boundary happens purely through interfaces, isolating the memory models.

---

## Summary

Vertex is broad enough to do what TypeScript does, and sharp enough to do what C++ does. The grammar never changes. The FFI layer is uniform. The compiler simply unlocks the types that mean something to your specific target, and strictly restricts the ones that don't.