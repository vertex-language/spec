# Vertex Language Grammar

## Specification — Channels & `select`

---

## 0. Overview

`chan T` is Vertex's single currency for moving values between execution contexts — the OS-level threads spawned by `thread` (`threads.md`) and the cooperative tasks spawned by `async` (`async.md`). Both sigils reduce to the same handle:

| Sigil | Spawns | Hands back |
| --- | --- | --- |
| `thread` (`threads.md` §1) | a real OS thread | `chan T` |
| `async` (`async.md` §3) | a reactor-scheduled task | `chan T` |

Because the handle is identical either way, a value can be produced on one side of the boundary and consumed on the other without any adapter — a `thread` can write into a channel that an `async` function later reads out of, and vice versa. This document covers the channel type itself, how each sigil populates one, and `select{}`, the one statement that waits on several channels at once.

---

## 1. Construction

Channels are a built-in generic type, constructed with square-bracket type parameters and an optional capacity argument:

```vertex
// Unbuffered channel (synchronous rendezvous)
let ch1 = chan[float32]()

// Buffered channel (capacity of 64 elements)
let ch2 = chan[int32](64)
```

* **Memory & Ownership:** `chan T` is an implicitly heap-resident handle (a container exception matching `[]T`, foundation §7). Copying the handle bumps its internal refcount; sending and receiving values over it obeys standard ownership rules (ownership.md).
* **Failure Mode:** Channel creation behaves like native array allocation — an out-of-memory error triggers a runtime panic rather than returning a boundary tuple.

---

## 2. Producing a Channel — the Two Sigils

### 2.1 `thread` — Auto-Channeling a Single Return

When a `thread`-spawned function returns a single value `T`, the call expression itself evaluates to a receive-only channel (`chan T`) carrying exactly that one item:

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)

let final_data = worker.receive()   // blocks the OS thread until ready
```

### 2.2 `async` — Auto-Channeling a Spawned Task

`async` as a call-site prefix (`async.md` §3) works the same way: it fires an `async` function concurrently without waiting for it, and the call expression evaluates to a receive-only `chan T`:

```vertex
let task = async fetch_data()
let result = await task.receive()   // suspends the task until ready
```

### 2.3 Streams — Explicit Channels

To move more than one value over time, construct a channel yourself and pass it in as an ordinary argument, rather than relying on auto-channeling:

```vertex
let out_stream = chan[float32](64)

thread func(data: []float32, ch: chan float32) {
    for chunk in data {
        ch.send(process(chunk))
    }
    ch.close()
}(dataset, out_stream)

while true {
    let chunk, err = out_stream.tryReceive()
    if err != "" {
        break   // channel closed and drained
    }
    print(chunk)
}
```

This same shape is how a `thread` hands a stream to an `async` consumer (§5) — nothing about explicit-channel construction differs by which sigil is on the producing end.

---

## 3. Channel Method Matrix

| Method | Waits? | Return Type | Description |
| --- | --- | --- | --- |
| `.send(val)` | Yes | `void` | Blocks the calling OS thread if the buffer is full. |
| `.receive()` | Yes | `T` | See §3.1 — waits until a value arrives; *how* it waits depends on calling context. |
| `.trySend(val)` | No | `bool` | Returns `false` if the buffer is full. |
| `.tryReceive()` | No | `(T, string)` | Returns the standard error tuple if empty or closed. |
| `.close()` | No | `void` | Closes the channel; signals no more values. |

```vertex
let val, err = ch.tryReceive()
if err != "" {
    // handle empty or closed channel
}
```

### 3.1 `.receive()` Has Two Wait Modes

`.receive()` is the one method on this table whose waiting mechanism is not fixed — it depends on where it's called from:

* **Called bare**, outside `await`, in an ordinary or `thread`-spawned context — it **blocks the calling OS thread** until a value arrives. This is the mode used throughout §2.1's and §2.3's examples above.
* **Called as `await ch.receive()`, inside an `async` function** — it **suspends the task** on the reactor (`async.md` §2) instead of blocking a thread. This is the only way `.receive()` is legal to reach from `async` code — a bare `.receive()` inside an `async` function would block the underlying OS thread and starve the reactor (`async.md` §4's warning on blocking calls applies here directly).

```vertex
// outside async — bare, blocks the thread
let v = ch.receive()

// inside an async function — await, suspends the task
func handle() async {
    let v = await ch.receive()
}
```

There is no third form and no ambiguity at a given call site: whether `.receive()` blocks or suspends is fully determined by whether it's written under `await`, which is itself only legal inside an `async` function (`async.md` §2.2).

---

## 4. `select{}`

`select{}` waits on a fixed set of channel operations and proceeds with whichever one becomes ready first.

### 4.1 Rule 1 — Cases Are Channel Operations Only

Every `case` in a `select{}` must be a `.receive()` or `.tryReceive()` call on a `chan T`. No other expression is legal in case position — not a bare async call, not an arbitrary function, nothing else.

### 4.2 Rule 2 — Wait Mode Is Inherited From Context, Not Chosen Per-Case

`select{}` introduces no waiting behavior of its own; every case waits exactly the way §3.1 says `.receive()` waits in that context:

```vertex
// ordinary function — every case bare, blocks the OS thread
select {
case a = task1.receive():
    print("Task 1 completed first")
case b = task2.receive():
    print("Task 2 completed first")
default:
    print("No data ready; skipping...")
}
```

```vertex
// async function — every case awaited, suspends the task
func race() async {
    select {
    case n, err = await conn_ch.receive():
        // ...
    case v = await compute_ch.receive():
        // ...
    }
}
```

### 4.3 Rule 3 — No Mixing Bare and `await` Cases

A single `select{}` must be entirely bare or entirely `await`-prefixed. One mode blocks an OS thread; the other suspends a task on the reactor — there is no "first ready wins" across two different wait primitives, so mixing them within one statement is illegal.

### 4.4 Rule 4 — `default:`

An optional `default:` case makes the whole statement non-blocking: if no other case is immediately ready, `default:` runs instead of waiting. This holds identically whether the surrounding cases are bare or `await`ed.

### 4.5 Manual Polling (No `select`)

Where `select{}`'s "race a fixed case list" shape doesn't fit, `.tryReceive()` can be polled directly, combined with a manual yield to avoid pegging the CPU:

```vertex
while true {
    let a, err1 = task1.ryReceive()
    if err1 == "" { break }

    let b, err2 = task2.tryReceive()
    if err2 == "" { break }

    runtime.yield()   // cooperatively yield execution slice
}
```

---

## 5. Pipeline — `thread` → `chan` → `async`

Because §2.1 and §2.2 both terminate in the same `chan T`, a value can cross from OS-thread-parallel work into reactor-scheduled work through one shared channel, with no conversion step:

```vertex
// Main: set up the pipe, hand one end to a thread
let pipe = chan[float32](64)

thread func(data: []float32, ch: chan float32) {
    for chunk in data {
        ch.send(crunch_numbers(chunk))   // producer: runs on an OS thread
    }
    ch.close()
}(dataset, pipe)

// Async: consume the same channel cooperatively
func drain(ch: chan float32) async {
    while true {
        let v, err = await ch.receive()
        if err != "" {
            break   // closed and drained
        }
        await process(v)
    }
}
```

The `thread` side never touches `await`; the `async` side never blocks a thread. `pipe` is the entire contract between them — the same channel, read on one end with a blocking producer and drained on the other with a suspending consumer.