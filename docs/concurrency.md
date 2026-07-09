# Vertex Language Grammar

## Specification 2.2 — Concurrency

---

## 1. The Execution Reality Map

| Prefix Sigil | The Vertex Abstraction |
|---|---|
| `thread` | Shared-memory concurrency |
| `async` | State machine, scheduler-driven |

---

## 2. Execution Modifiers (Prefix Sigils)

```vertex
let a = async fetch_network(id: 1)
let b = thread heavy_compute(data: x)
```

* `thread` and `async` are mutually exclusive prefixes on a call expression, not function qualifiers.
* The same function, written once with no qualifier, may be called with either sigil at different call sites.
* Calls returning a value (`-> T`) become channel-returning expressions — see §3.

---

## 3. The Channel Dichotomy: Single-Return vs. Streams

### Path A: The Single-Return (Auto-Channeling)

```vertex
let worker = thread func(seed: int32) -> float32 {
    return crunch_numbers(seed)
}(105)

let final_data = worker.receive()
```

### Path B: The Stream (Explicit Channels)

```vertex
let out_stream: chan float32 = {cap: 64}

thread func(data: [float32], ch: chan float32) {
    for chunk in data {
        ch.send(process(chunk))
    }
    ch.close()
}(dataset, out_stream)

while let chunk = out_stream.tryReceive() {
    print(chunk)
}
```

---

## 4. Channels

### 4.1 Channel Initialization

```vertex
// unbuffered — blocks on send until receiver is ready
let ch1: chan float32 = {}

// buffered — capacity set via cap field
let ch2: chan int32 = {cap: 64}
```

### 4.2 Channel API

```vertex
ch.send(val)          // blocking send — waits if buffer is full
ch.receive()          // blocking receive — waits until a value arrives
ch.trySend(val)       // non-blocking send — returns bool, false if full
ch.tryReceive()       // non-blocking receive — returns immediately
ch.close()            // closes the channel, signals no more values
```

```vertex
if let val = ch.tryReceive() {
    print(val)
}
```

| Method | Blocking | Returns |
|---|---|---|
| `.send(value)` | yes | `void` |
| `.receive()` | yes | `T` |
| `.trySend(v)` | no | `bool` |
| `.tryReceive()` | no | `T?` |
| `.close()` | no | `void` |

---

## 5. Multiplexing (`select` and Polling)

```vertex
let task1 = thread crunch_data()
let task2 = thread fetch_network()

var waiting = true
while waiting {
    if let a = task1.tryReceive() {
        print("Task 1 done")
        waiting = false
    } else if let b = task2.tryReceive() {
        print("Task 2 done")
        waiting = false
    } else {
        runtime.yield()
    }
}
```

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