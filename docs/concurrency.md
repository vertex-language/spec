# Vertex Language Grammar

## Specification 2.2 — Concurrency

---

## 1. The Execution Reality Map

| Prefix Sigil | The Vertex Abstraction |
| --- | --- |
| `thread` | Shared-memory concurrency — a real OS thread |
| `async` | State machine, scheduler-driven |

---

## 2. Execution Modifiers (Prefix Sigils)

```vertex
let a = async fetch_network(id: 1)
let b = thread heavy_compute(data: x)
```

* `thread` and `async` are mutually exclusive prefixes on a **call
  expression**, not function qualifiers.
* The same function, written once with no qualifier, may be called with
  either sigil at different call sites — or with none, synchronously.
* Calls returning a value (`-> T`) become channel-returning expressions
  — see §3.

---

## 3. The Channel Dichotomy: Single-Return vs. Streams

### Path A: The Single-Return (Auto-Channeling)

A `thread`/`async` call whose function returns `T` evaluates to a
receive-only channel of `T` that will carry exactly one value:

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)

let final_data = worker.receive()
```

### Path B: The Stream (Explicit Channels)

For many values, construct a channel and hand it to the worker as an
ordinary argument:

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
        break
    }
    print(chunk)
}
```

---

## 4. Channels

### 4.1 Construction

A channel is a built-in generic type, constructed like any other
instantiable type (generics §5) — type argument in `[...]`, capacity as
an ordinary constructor argument:

```vertex
// unbuffered — blocks on send until a receiver is ready
let ch1 = chan[float32]()

// buffered — capacity as the constructor argument
let ch2 = chan[int32](64)

// with an explicit type annotation
let ch3: chan float32 = chan[float32]()
```

There is no `new(chan T)` and no `make` — `new` is raw fallible
allocation only (memory §11), and channels need no special form.

**Ownership.** `chan T` is a handle to implicitly heap-resident state —
the container exception (ownership §2), same story as `[]T` and
`map[K]V`. The handle travels under the ordinary conventions; the
channel's internal storage follows the handle. Construction returns bare
`chan T`, not a boundary tuple: allocation failure is a panic, matching
`[]T`'s `push`, which also allocates with no error channel.

### 4.2 Channel API

```vertex
ch.send(val)          // blocking send — waits if buffer is full
ch.receive()          // blocking receive — waits until a value arrives
ch.trySend(val)       // non-blocking send — returns bool, false if full
ch.tryReceive()       // non-blocking receive — returns immediately
ch.close()            // closes the channel, signals no more values
```

```vertex
let val, err = ch.tryReceive()
if err == "" {
    print(val)
}
```

| Method | Blocking | Returns |
| --- | --- | --- |
| `.send(value)` | yes | `void` |
| `.receive()` | yes | `T` |
| `.trySend(v)` | no | `bool` |
| `.tryReceive()` | no | `(T, string)` |
| `.close()` | no | `void` |

`.tryReceive()` is the standard error tuple (foundation §35): on
"nothing available" or "closed and drained," the value slot is `T`'s
zero value and the string is non-empty. No special sentinel, no
second bool — absence is the tuple, as everywhere else.

---

## 5. Multiplexing (`select` and Polling)

### 5.1 Manual Polling

```vertex
let task1 = thread crunch_data()
let task2 = thread fetch_network()

var waiting = true
while waiting {
    let a, err1 = task1.tryReceive()
    if err1 == "" {
        print("Task 1 done")
        waiting = false
        continue
    }

    let b, err2 = task2.tryReceive()
    if err2 == "" {
        print("Task 2 done")
        waiting = false
        continue
    }

    runtime.yield()
}
```

### 5.2 `select`

```vertex
select {
case a = task1.receive():
    print("Task 1 done")
case b = task2.receive():
    print("Task 2 done")
default:
    // adding 'default' makes the select instantly non-blocking
    print("Doing other work...")
}
```