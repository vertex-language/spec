## Channels & `select`

---

## 0. Overview

`chan T` is Vertex's single currency for moving values between execution contexts —
the OS-level threads spawned by `thread` (`threads.md`) and the cooperative tasks
spawned by `async` (`async.md`). Both sigils reduce to the same handle:

| Sigil | Spawns | Hands back |
| --- | --- | --- |
| `thread` (`threads.md` §1) | a real OS thread | `chan T` |
| `async` (`async.md` §3) | a reactor-scheduled task | `chan T` |

Because the handle is identical either way, a value can be produced on one side of
the boundary and consumed on the other without any adapter — a `thread` can write
into a channel that an `async` function later reads out of, and vice versa.

`gpu` and `npu` are the two launch prefixes that do *not* appear in that table:
a device launch is synchronous and returns a host-typed value directly
(`accel.md` §1.3). This document covers the channel type itself, how each of the two
concurrent sigils populates one, and `select{}`, the one statement that waits on
several channels at once.

---

## 1. Construction

Channels are a built-in generic type with their own construction form — a
`ChanConstructor`, not an ordinary call — taking square-bracket type parameters and
an optional capacity argument:

```vertex
// Unbuffered channel (synchronous rendezvous)
let ch1 = chan[float32]()

// Buffered channel (capacity of 64 elements)
let ch2 = chan[int32](64)
```

`ChanType` (`chan float32`, in a parameter or field) and `ChanConstructor`
(`chan[float32]()`, in an expression) are the only two forms of `chan`, and they
never compete: a type position admits no expression. A channel type carries no
direction — there is no send-only or receive-only spelling, and the "receive-only"
language in §2 describes how a handle is *used*, not a type the compiler enforces.

* **Memory & Ownership:** `chan T` is an implicitly heap-resident handle (a
  container exception matching `[]T`, foundation §22). Copying the handle bumps its
  internal refcount; sending and receiving values over it obeys standard ownership
  rules (`ownership.md`).
* **Failure Mode:** Channel creation behaves like native array allocation — an
  out-of-memory error triggers a runtime panic rather than returning a boundary
  tuple. This is the container side of the split `memory.md` §11 draws: `new`
  reports, containers panic.

---

## 2. Producing a Channel — the Two Sigils

### 2.1 `thread` — Auto-Channeling a Single Return

When a `thread`-spawned function returns a single value `T`, the call expression
itself evaluates to a `chan T` carrying exactly that one item:

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)

let final_data = worker.receive()   // blocks the OS thread until ready
```

The callee is an ordinary function (`threads.md` §1) — nothing in its declaration
mentions a channel. The channel is produced by the *prefix*, at the call site.

### 2.2 `async` — Auto-Channeling a Spawned Task

`async` as a call-site prefix (`async.md` §3) works the same way: it fires an
`async` function concurrently without waiting for it, and the call expression
evaluates to a `chan T`:

```vertex
let task = async fetch_data()
let result = await task.receive()   // suspends the task until ready
```

The one difference from §2.1 is the callee: `thread` spawns an unmarked function,
`async` spawns an `async`-marked one. What comes back is the same type.

### 2.3 Streams — Explicit Channels

Auto-channeling carries exactly one value. To move more than one over time,
construct a channel yourself and pass it in as an ordinary argument:

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

The spawned function returns nothing, so there is no auto-channel to collide with
the explicit one. This same shape is how a `thread` hands a stream to an `async`
consumer (§5) — nothing about explicit-channel construction differs by which sigil
is on the producing end.

---

## 3. Channel Method Matrix

| Method | Waits? | Return Type | Description |
| --- | --- | --- | --- |
| `.send(val)` | Yes | *(none)* | Blocks the calling OS thread if the buffer is full. See §3.2. |
| `.receive()` | Yes | `T` | See §3.1 — waits until a value arrives; *how* it waits depends on calling context. |
| `.trySend(val)` | No | `bool` | Returns `false` if the buffer is full. |
| `.tryReceive()` | No | `(T, string)` | Returns the standard boundary tuple if empty or closed. |
| `.close()` | No | *(none)* | Closes the channel; signals no more values. |

`.send` and `.close` return nothing, so they write no `->` at all (foundation §19);
there is no `void` type name to give them.

```vertex
let val, err = ch.tryReceive()
if err != "" {
    // handle empty or closed channel
}
```

`.tryReceive()` collapses "nothing here yet" and "closed forever" into one non-empty
string, exactly as foundation §35.4 says absence and failure share one channel. A
consumer that must distinguish the two has nothing in the corpus to do it with; see
§6.

### 3.1 `.receive()` Has Two Wait Modes

`.receive()` is the one method on this table whose waiting mechanism is not fixed —
it depends on where it's called from:

* **Called bare**, outside `await`, in an ordinary or `thread`-spawned context — it
  **blocks the calling OS thread** until a value arrives. This is the mode used in
  §2.1's and §2.3's examples above.
* **Called as `await ch.receive()`, inside an `async` function** — it **suspends the
  task** on the reactor (`async.md` §2) instead of blocking a thread. This is the
  only way `.receive()` is legal to reach from `async` code — a bare `.receive()`
  inside an `async` function would block the underlying OS thread and starve the
  reactor (`async.md` §4's warning on blocking calls applies here directly).

```vertex
// outside async — bare, blocks the thread
let v = ch.receive()

// inside an async function — await, suspends the task
func handle() async {
    let v = await ch.receive()
}
```

There is no third form and no ambiguity at a given call site: whether `.receive()`
blocks or suspends is fully determined by whether it's written under `await`, which
is itself only legal inside an `async` function (`async.md` §2.2).

**`.receive()` returns `T` in both modes.** It does not become a tuple under
`await`. A receive on a closed and drained channel has no specified behaviour
anywhere in the corpus — every drain loop in this document therefore uses
`.tryReceive()`, which reports closure as a value. See §6.

### 3.2 `.send` Has Only One Wait Mode

`.send` blocks the calling OS thread when the buffer is full, and there is no
`await ch.send(...)` form. On an unbuffered channel it blocks until a receiver
arrives; on a buffered one, until a slot frees.

This is a genuine asymmetry with §3.1, and it constrains where an `async` producer
is safe: an `async` function sending into a channel whose consumer has fallen behind
will block its OS thread and starve the reactor. Until a suspending send exists
(§6), an `async` producer should either send on a channel it can prove has room, or
use `.trySend()` and handle `false`:

```vertex
func produce(ch: chan int32, v: int32) async {
    if !ch.trySend(v) {
        // buffer full — drop, retry later, or park on something else.
        // Do NOT fall back to ch.send(v): that blocks the reactor thread.
    }
}
```

The `thread` side has no such constraint. Blocking an OS thread is what a `thread`
is for.

---

## 4. `select{}`

`select{}` waits on a fixed set of channel operations and proceeds with whichever
one becomes ready first.

### 4.1 Rule 1 — Cases Are Channel Operations Only

Every `case` in a `select{}` must be a `.receive()` or `.tryReceive()` call on a
`chan T`. No other expression is legal in case position — not a bare async call, not
an arbitrary function, nothing else.

This is enforced by the grammar's `ChannelCase`, whose only expression form is
`ChannelOp = CallExpr | "await" CallExpr` — "a call and nothing else." To race a
standalone `async` call, spawn it first with the `async` prefix (§2.2), which hands
back a `chan T`, and put the `.receive()` on *that* in case position.

### 4.2 Rule 2 — Wait Mode Is Inherited From Context, Not Chosen Per-Case

`select{}` introduces no waiting behaviour of its own. It does not dispatch on a
case's type, does not race heterogeneous sources, and adds nothing to `.receive()`.
Every case waits exactly the way §3.1 says `.receive()` waits in that context — the
only question the statement itself answers is which ready case runs.

```vertex
// ordinary function — every case bare, blocks the OS thread
select {
case let a = task1.receive():
    print("Task 1 completed first")
case let b = task2.receive():
    print("Task 2 completed first")
default:
    print("No data ready; skipping...")
}
```

```vertex
// async function — every case awaited, suspends the task
func race(conn_ch: chan int32, compute_ch: chan float32) async {
    select {
    case let n = await conn_ch.receive():
        print(n)
    case let v = await compute_ch.receive():
        print(v)
    }
}
```

A case may introduce its own bindings with `let` or `var`, as above, or assign to
pre-declared targets. Bindings introduced by a case are scoped to that clause's
statement list.

### 4.3 Rule 3 — No Mixing Bare and `await` Cases

A single `select{}` must be entirely bare or entirely `await`-prefixed. One mode
blocks an OS thread; the other suspends a task on the reactor — there is no "first
ready wins" across two different wait primitives, so mixing them within one
statement is illegal.

Since `await` is only legal inside an `async` function, the mode is effectively
fixed by where the `select{}` is written. The rule exists to catch a bare case that
slipped into an `async` body, which would otherwise block the reactor silently.

### 4.4 Rule 4 — `default:`

An optional `default:` case makes the whole statement non-blocking: if no other case
is immediately ready, `default:` runs instead of waiting. This holds identically
whether the surrounding cases are bare or `await`ed. At most one `default` clause.

### 4.5 Manual Polling (No `select`)

Where `select{}`'s "race a fixed case list" shape doesn't fit — a variable number of
channels, or a set that changes between iterations — `.tryReceive()` can be polled
directly, combined with a manual yield to avoid pegging the CPU:

```vertex
while true {
    let a, err1 = task1.tryReceive()
    if err1 == "" {
        break
    }

    let b, err2 = task2.tryReceive()
    if err2 == "" {
        break
    }

    runtime.yield()   // cooperatively yield execution slice
}
```

---

## 5. Pipeline — `thread` → `chan` → `async`

Because §2.1 and §2.2 both terminate in the same `chan T`, a value can cross from
OS-thread-parallel work into reactor-scheduled work through one shared channel, with
no conversion step:

```vertex
// Main: set up the pipe, hand one end to a thread
let pipe = chan[float32](64)

thread func(data: []float32, ch: chan float32) {
    for chunk in data {
        ch.send(crunch_numbers(chunk))   // producer: blocks an OS thread when full
    }
    ch.close()
}(dataset, pipe)

// Async: consume the same channel cooperatively
func drain(ch: chan float32) async {
    while true {
        let v, err = ch.tryReceive()
        if err != "" {
            break                        // closed and drained — or just empty (§6)
        }
        await process(v)
    }
}
```

The `thread` side never touches `await`; the `async` side never blocks a thread.
`pipe` is the entire contract between them.

The consumer above uses `.tryReceive()` rather than `await ch.receive()` for the
reason §3.1 gives: `.receive()` returns a bare `T` and has no way to report that the
producer closed the channel. That makes this loop **busy-wait when the channel is
merely empty** — it cannot distinguish "nothing yet" from "no more ever," so it
exits on both. A production drain needs the suspending-receive-with-closure form
that does not yet exist; §6 states the gap. This example is correct against the
specified surface and is not the shape the language should end up with.