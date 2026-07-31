# Vertex Language Grammar

## Specification — Threads

---

## 0. Overview

`thread` is Vertex's model for real, shared-memory, OS-level parallelism — the tool for CPU-bound work that needs actual concurrent execution across cores, as opposed to cooperative multiplexing on a single execution context.

This document covers exactly one thing: the `thread` sigil and what it does to a call expression. What a spawned call *hands back*, and how to wait on it, consume it, or race it against other sources, is a separate concern — see `channels.md`.

---

## 1. The `thread` Sigil

```vertex
let b = thread heavy_compute(data: x)
```

* `thread` is a **call-expression prefix**, not a function qualifier. It modifies how a call is *scheduled*, not the callee's declaration.
* The callee is an ordinary native function. Its signature and body are written exactly as they would be for a direct, unprefixed call — nothing about a function's declaration changes based on whether some call site happens to spawn it with `thread`.
* `thread` runs the call on a real OS-level thread, concurrently with the caller.

```vertex
func heavy_compute(data: []float32) -> float32 {
    // ordinary function — no thread-specific syntax here
    return crunch(data)
}

let b = thread heavy_compute(data: x)   // spawned onto an OS thread
let c = heavy_compute(data: x)          // same function, called directly
```

---

## 2. Spawning Anonymous Work

Because `thread` is a call-expression prefix, it applies equally to an inline anonymous function:

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)
```

The anonymous function above is ordinary Vertex — same capture rules as any other closure (foundation §32). `thread` only changes where the call executes, not what's legal inside its body.

---

## 3. What a Spawned Call Returns

A `thread`-prefixed call does not hand back the callee's return value directly — see `channels.md` for what it returns instead, and for how to retrieve a result, stream multiple values out of a running thread, or wait on several spawned calls at once alongside other sources.