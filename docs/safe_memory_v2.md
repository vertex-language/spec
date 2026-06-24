# Vertex Language: Memory & Runtime Safety (v2)

## Philosophy & The Living Standard

100% flawless software and absolute, mathematically perfect memory safety are industry myths. Even the most highly regarded safe systems languages rely on localized unsafe boundaries to function. 

Therefore, the goal of Vertex's memory architecture is not a theoretical utopia, but **pragmatic risk management**. 

This document is a living standard. The features listed below represent our baseline structural guardrails—designed to eliminate the most common, catastrophic human errors (like buffer overflows and null dereferences) while preserving the developer's ability to optimize for blistering execution speed. This list of safety features will grow, shift, and be adjusted over time as the language evolves and new attack vectors or hardware realities emerge.

Vertex gives the developer absolute control over execution contexts (`async`, `thread`, `gpu`) and raw pointers (`*T`). By providing these foundational safety layers, we ensure the "default" path is secure, while explicitly marking where the developer takes the safety rails off for raw performance.

---

## 1. Fat Pointers & Runtime Bounds Checking

**The Exploit Prevented:** Stack-smashing buffer overflows.
**Performance Hit:** **Low**

In standard C, an array passed to a function decays into a raw pointer, stripping the compiler of its size. In Vertex, dynamic arrays (`[T]`) and string slices are lowered as **Fat Pointers**.

### How it works
Under the hood, `[T]` lowers to a C struct:
```c
typedef struct {
    T* data;
    uint64_t length;
    uint64_t capacity;
} VertexArray;

```

Every time the developer writes `buf[i]`, the compiler silently emits:

```c
if (i >= buf.length) { vertex_panic("index out of bounds"); }

```

### The Speed Reality

Modern branch predictors inside CPUs are incredibly smart. Because `i >= length` evaluates to `false` 99.999% of the time, the CPU predicts the branch perfectly. The performance cost is usually just a single instruction per access.

---

## 2. Null Pointer Dereference Prevention (`T?`)

**The Exploit Prevented:** Segfaults (NullPointerException) and remote Denial of Service.
**Performance Hit:** **Zero** (Compile-time) / **Low** (Runtime)

Raw pointers (`*T`) are inherently unsafe if they can secretly be `NULL`. Vertex enforces null-safety strictly through the type system via Optionals (`?`).

### How it works

A standard pointer `var p: *int32` **cannot** be assigned `nil`. The compiler refuses to compile it.
If a developer needs a nullable pointer, they must use `var p: *int32?`. The compiler then forces the developer to unwrap it using `if let` before dereferencing:

```vertex
if let valid_p = p {
    // valid_p is guaranteed to be non-NULL here
}

```

### The Speed Reality

Because the compiler forces the check before the C lowering, there is **Zero** hidden runtime cost. The runtime cost only exists when the developer explicitly writes the `if let` branch, which they would have had to do anyway to safely handle the absence of a value.

---

## 3. Definite Initialization (Zeroing Memory)

**The Exploit Prevented:** Information leaks (reading passwords/keys left in RAM by other programs).
**Performance Hit:** **Low**

In standard C, allocating an array leaves the memory uninitialized, meaning it contains whatever garbage data was sitting in RAM previously.

### How it works

Vertex fixed arrays (`var buf: [uint8; 1024]`) implicitly zero-fill. The compiler automatically injects a `memset(buf, 0, 1024)` at the allocation site.

### The Speed Reality

`memset` is hyper-optimized in C standard libraries (often utilizing SIMD instructions to zero out massive chunks of memory per clock cycle). The hit is practically invisible unless you are allocating gigabytes of temporary arrays inside a tight `while` loop.

---

## 4. Arithmetic Overflow Traps

**The Exploit Prevented:** Integer overflow (e.g., bypassing an array length check or corrupting financial logic).
**Performance Hit:** **Low to Medium**

### How it works

Standard arithmetic operators (`+`, `-`, `*`) automatically trap and panic if the integer overflows its maximum bounds. If the developer *wants* the integer to wrap around (such as in cryptography or hashing algorithms), they must use Vertex's explicit overflow operators (`&+`, `&-`, `&*`).

### The Speed Reality

The compiler checks the CPU's internal overflow flag after the operation. This introduces branching logic into math-heavy code. While still fast, if placed inside a matrix multiplication loop running millions of times, it becomes a **Medium** hit. (For heavy compute, developers should rely on the `gpu` execution sigil).

---

## 5. Explicit Variable Shadowing Rules

**The Exploit Prevented:** Logical business flaws (accidentally modifying the wrong variable with the same name).
**Performance Hit:** **Zero**

### How it works

Vertex strictly controls variable shadowing. You cannot accidentally declare `var count = 0` inside an `if` block if `var count = 10` already exists in the parent function scope.

### The Speed Reality

This is purely a static analysis check during the parsing phase. It has zero effect on the compiled binary and incurs no runtime cost.

---

## Summary of Defensive Posture

| Feature | Prevents | Speed Impact | Phase |
| --- | --- | --- | --- |
| **Fat Pointers** | Buffer Overflows | Low | Runtime |
| **Strict Optionals (`T?`)** | Null Dereference | Zero | Compile-Time |
| **Definite Init** | Info Leaks | Low | Runtime |
| **Math Overflow Traps** | Integer Wrap Exploits | Low/Med | Runtime |
| **Shadowing Rules** | Logical Variable Bugs | Zero | Compile-Time |