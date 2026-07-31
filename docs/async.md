# Vertex Language Grammar

## Specification — Async

---

## 0. Overview

`async` and `await` form Vertex's native approach to non-blocking I/O. This cooperative model multiplexes OS-level I/O waits (e.g., epoll, kqueue, io_uring) efficiently onto a runtime reactor.

It is distinct from the `thread` concurrency model:

* **`async` / `await**`: For I/O-bound tasks where the system cooperatively waits.
* **`thread`**: For CPU-bound tasks requiring real OS-level, shared-memory parallelism.

---

## 1. The `async` Marker (Signatures)

Functions containing a real OS-level poll point (where the kernel might yield "not yet") must be marked with `async`.

```vertex
func (c: Conn) read(buf: mut []uint8) async -> (int32, string) {
    // ...
}

```

By marking a function `async`, you inform the compiler that this function returns a state machine (conceptually similar to a Promise or Future) rather than blocking the thread outright.

---

## 2. The `await` Keyword (Yielding)

To retrieve the value from an `async` function and cooperatively pause the current execution until that value is ready, you must use the `await` keyword.

```vertex
let n, err = await conn.read(buf)

```

### 2.1 Explicit Suspension

`await` acts as an explicit yield point. When the compiler sees `await`, it knows to pause the current function, save its state, and return control to the event loop until the network or disk is ready.

### 2.2 Function Coloring

Because `await` requires a state machine to pause execution, you can generally only use `await` inside another `async` function. (The `main` function is the singular exception, acting as the root reactor entry point).

---

## 3. Spawning Concurrent Background Tasks

To fire off an `async` function concurrently without waiting for it to finish, use `async` as a call-site prefix (identical to how the `go` keyword works in Golang).

This tosses the state machine onto the reactor loop and immediately returns a receive-only channel (`chan T`).

```vertex
// Fire and forget (inline kickoff)
async handleClient(conn.transfer())

// Inline anonymous background routines
async func() {
    await do_background_work()
}()

// Kick off and wait later via the returned channel
let task = async fetch_data()
let result = await task.receive() 

```

---

## 4. When to Use `async`

**Rule:** Mark a function `async` only if there is a code path where the kernel can return a "not ready" state.

| Call | Can the kernel delay? | Declared `async`? |
| --- | --- | --- |
| `conn.read(buf)` | Yes (no bytes arrived) | Yes |
| `listener.accept()` | Yes (no pending connection) | Yes |
| `conn.fd()` | No (struct field read) | No |
| `conn.setNoDelay(true)` | No (applied instantly) | No |
| `clock.now()` | No (reads monotonic counter) | No |

**Warning on Blocking:** Putting a synchronous, blocking function (like a heavy `while` loop or OS sleep) inside an `async` function will block the underlying OS thread, starving the event loop. For intentional delays, use `await time.Sleep()`.

---

## 5. `select{}` Multiplexing

`select{}` dispatches per `case` by the receiver's static type, seamlessly racing multiple awaited tasks or channels against each other. Every case must be a channel receive operation (`.receive()` / `.tryReceive()`) — see `channels.md` §4.1. To race a standalone `async` call (rather than an explicit `chan T`), spawn it first with the `async` call-site prefix (`async.md` §3), which hands back a `chan T`, and put the `.receive()` on *that* in case position:

```vertex
let connReadTask = async conn.read(buf)

select {
case n, err = await connReadTask.receive():
    // Reactor submission via `await`
case v = await computeTask.receive():
    // Channel wait via `chan T`
}

```

---

## 6. Custom Reactors

Vertex defaults to `builtins/async` (wrapping `io_uring`/`kqueue`), but does not force a runtime. Developers can write their own dispatch loops against platform primitives if the default reactor's scheduling policy requires tuning.

---

## 7. Language Comparison: Concurrency Models

Different languages approach I/O multiplexing with distinct architectural tradeoffs. Vertex aligns with the explicit readability of Rust and JavaScript, while adopting the lightweight kickoff ergonomics of Go.

| Feature | Golang | JavaScript | Rust | Vertex |
| --- | --- | --- | --- | --- |
| **Architecture** | Stackful (Goroutines) | Event Loop (Promises) | Stackless State Machine | Stackless State Machine |
| **Spawning** | `go func()` | Implicit | `tokio::spawn()` | `async func()` |
| **Detection** | Runtime | Statically Marked | Statically Marked | Statically Marked |
| **Contagious?** | No | Yes (`async`/`await`) | Yes (`async`/`.await`) | Yes (`async`/`await`) |
| **Memory / GC** | GC-managed heap | GC-managed heap | Zero-cost / No GC | Zero-cost / No GC |

### 7.1 Stackless Performance Gains

Stackless architectures (Rust, Kotlin, Vertex) compile suspension points into flat, discrete state machines rather than pausing entire execution stacks. This yields specific performance advantages over Stackful architectures (Go, OS threads):

1. **Lower Memory Footprint:** Stackful models must allocate a minimum stack block (e.g., Go's initial 2KB per goroutine). Stackless models allocate only the exact byte-width of the variables kept alive across the suspend point, allowing millions of concurrent waits in fractions of the memory.
2. **Faster Context Switching:** Waking a stackless task is a direct function call branching on an integer state tag. Waking a stackful task requires swapping out CPU registers and stack pointers, which carries higher latency.

### 7.2 The Golang Tradeoff (Why it lacks coloring)

Golang famously avoids function coloring (explicit `async`/`await`), but this comes at a strict architectural cost: **runtime interception**.

Go achieves its colorless design by forcing all network and file operations through its own standard library, which silently intercepts blocking syscalls and parks the goroutine on Go's hidden background event loop. While ergonomic, the tradeoffs for systems programming are severe:

* **No Custom Reactors:** You cannot build your own async flow from scratch or swap out the event loop concept (e.g., dropping in a specialized `io_uring` or `kqueue` reactor).
* **Kernel Lock-in:** You cannot easily utilize newer native kernel features or target custom/bare-metal OS kernels without porting and rewriting the massive Go runtime scheduler for that specific platform.
* **The FFI Choke Point:** If you use native C or C++ methods that block (via cgo), Go's illusion breaks. The blocking C code will completely halt the underlying OS thread, starving the scheduler and severely degrading system performance.

Vertex accepts function coloring (`async`/`await`) precisely to keep the runtime transparent and modular. By exposing the state machine explicitly, Vertex allows developers to write custom reactors (§6) and safely interop with C/C++ without hidden runtime heuristics breaking the system.

---

## 8. Low-Level FD Readiness — `builtins/async`

### 8.1 Philosophy

`async`/`await` (§1–§2) are the *language*'s suspension mechanism — they say "this function may yield." They say nothing about *what* it waits on. That's a separate, lower job: turning a kernel readiness fact into a suspension point. Vertex gives that job exactly two functions, and stops there deliberately — per §7.2, the alternative is Go's path, where the readiness primitive is hidden inside a standard library you can't swap out or build alongside.

```vertex
func async.Readable(fd: int32) async -> string
func async.Writable(fd: int32) async -> string
```

* **Scope: socket file descriptors.** These two functions suspend the calling task until the reactor observes `fd` as readable or writable, respectively, per the platform's poll primitive (`epoll`, `kqueue`, or an `io_uring` poll op). They are the exact primitive a socket wrapper needs to turn a `EAGAIN` from a non-blocking syscall into a real suspension instead of a busy-loop or a blocked thread.
* **Not a socket type.** `Readable`/`Writable` take a bare `int32` — nothing about the fd's kind, protocol, or origin. They carry no opinion about what `fd` is; they only answer "is it ready." Any userspace wrapper (`TcpConn`, a Unix domain socket, a raw `LibC.socket()` call never wrapped at all) reaches the same two functions the same way.
* **This is the seam custom reactors (§6) hang off of.** A reactor swap means reimplementing `Readable`/`Writable` against a different platform primitive — not rewriting every wrapper built on top of them.
* **Other fd kinds are future scope, not a different name.** Pipes, `eventfd`, TTYs, and regular files raise distinct readiness questions (see the platform note below) and are deliberately left out of this pass. When they're added, they'll reuse `async.Readable`/`Writable` where the semantics genuinely match a socket's readiness model — new fd kinds are not a reason to mint new function names.

### 8.2 Signature

| Function | Blocks the OS thread? | Suspends the task? | Returns |
| --- | --- | --- | --- |
| `async.Readable(fd)` | No | Yes, until `fd` is readable | `string` — `""` on success, non-empty on reactor error (e.g. fd closed underneath the wait) |
| `async.Writable(fd)` | No | Yes, until `fd` is writable | `string` — same convention |

Errors follow the standard boundary-tuple convention (foundation §35): check the string before trusting that the wait resolved cleanly.

### 8.3 The Retry Pattern

`Readable`/`Writable` don't perform I/O themselves — they only resolve *when* a subsequent non-blocking syscall is worth retrying. Every socket operation in Vertex follows the same three-line shape:

```vertex
while true {
    let n, err = LibC.read(fd, buf, buf.length as uint64)
    if err == "" {
        return n as int32, ""
    }
    if err != "EAGAIN" {
        return 0, err
    }

    let werr = await async.Readable(fd)
    if werr != "" {
        return 0, werr
    }
}
```

Try the syscall → on `EAGAIN`, `await` the readiness function → retry. This is the entire mechanism; there is no hidden queuing or batching beneath it that a wrapper author needs to reason about.

### 8.4 Example — Socket Wrapper

```vertex
class TcpListener {
    fd: int32
}

func (l: TcpListener) accept() async -> (TcpConn, string) {
    while true {
        var addr: SockAddrIn
        var len:  socklen_t = sizeof(SockAddrIn) as socklen_t

        let fd, err = LibC.accept(l.fd, addr, len)
        if err == "" {
            return TcpConn{fd: fd}, ""
        }
        if err != "EAGAIN" {
            return TcpConn{}, err
        }

        let werr = await async.Readable(l.fd)
        if werr != "" {
            return TcpConn{}, werr
        }
    }
}

struct TcpConn {
    fd: int32
}

func (c: TcpConn) read(buf: mut []uint8) async -> (int32, string) {
    while true {
        let n, err = LibC.read(c.fd, buf, buf.length as uint64)
        if err == "" {
            return n as int32, ""
        }
        if err != "EAGAIN" {
            return 0, err
        }

        let werr = await async.Readable(c.fd)
        if werr != "" {
            return 0, werr
        }
    }
}

func (c: TcpConn) write(buf: []byte, count: int32) async -> (int32, string) {
    var sent: int32 = 0
    while sent < count {
        let n, err = LibC.write(c.fd, buf, (count - sent) as uint64)
        if err == "" {
            sent += n as int32
            continue
        }
        if err != "EAGAIN" {
            return sent, err
        }

        let werr = await async.Writable(c.fd)
        if werr != "" {
            return sent, werr
        }
    }
    return sent, ""
}
```

Nothing in `TcpListener`/`TcpConn` is compiler-privileged — this is exactly the code any developer writes to wrap a new fd kind. `async.Readable`/`Writable` are the entire contract between userspace and the reactor.

### 8.5 Precondition — Non-Blocking Fds

`Readable`/`Writable` only make sense against a fd opened non-blocking (e.g. `SOCK_NONBLOCK` at `socket()` creation). Calling a blocking syscall against a fd and awaiting readiness afterward doesn't compose — the syscall would have already blocked the thread before `EAGAIN` ever had a chance to appear. Setting the non-blocking flag at fd creation is the caller's responsibility; §8.1–§8.4 assume it throughout.

### 8.6 Platform Note — Scope Boundary

`Readable`/`Writable` report real kernel readiness for sockets (and, by the same underlying mechanism, pipes and other poll-able fds) on every reactor backend (`epoll`, `kqueue`, `io_uring`). They are **not** currently specified for regular files: `epoll`/`kqueue` report a file fd as always-ready, so `Readable(fd)` on one returns immediately without a meaningful wait, while an `io_uring`-backed reactor could in principle give it real completion semantics. Resolving that gap — either by scoping file I/O to a `thread`-backed fallback or by giving files their own readiness contract — is left for a future revision, not solved by this section.