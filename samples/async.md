## Async

---

## 0. Overview

`async` and `await` are Vertex's native approach to non-blocking I/O. The model is
cooperative: many tasks share one OS thread, and a task that cannot proceed hands
control back to a reactor that multiplexes kernel-level I/O waits (`epoll`,
`kqueue`, `io_uring`).

It is distinct from the `thread` concurrency model:

* **`async` / `await`** — for I/O-bound work, where the system cooperatively waits.
* **`thread`** — for CPU-bound work needing real OS-level, shared-memory
  parallelism.

The two are not alternatives to choose between once. They compose through `chan T`,
which both sigils produce (`channels.md` §0), and a well-shaped program usually runs
both: threads for the crunching, tasks for the waiting.

---

## 1. The `async` Marker (Signatures)

A function containing a real OS-level poll point — somewhere the kernel might answer
"not yet" — must be marked `async`.

```vertex
func (c: TcpConn) read(buf: mut []byte) async -> (int32, string) {
    // ...
}
```

The marker sits after the parameter list and before the result (grammar, *Function
types and signatures*). It tells the compiler this function compiles to a state
machine rather than a body that blocks its thread outright.

A signature carries **at most one** marker: there is no `async gpu` function, and
`test` cannot combine with `async` either. The marker is part of the function's
*type* (foundation §31), so it is checked at the declaration and again at every call
site, and a `var f: func(mut []byte) async -> (int32, string)` carries it too.

Because `MethodRequirement` takes a full `Signature`, a constraint can require a
marked method:

```vertex
constraint Reader {
    func read(buf: mut []byte) async -> (int32, string)
}
```

---

## 2. The `await` Keyword (Yielding)

To retrieve the value from an `async` function and cooperatively pause until it is
ready, use `await`:

```vertex
let n, err = await conn.read(buf)
```

`await` is a unary operator over a `UnaryExpr`, so it binds to the call and the
tuple destructure happens outside it — the line above awaits `conn.read(buf)` and
then unbuilds the result.

### 2.1 Explicit Suspension

`await` is an explicit yield point. Where the compiler sees it, it pauses the
current function, saves the state that is live across the suspension, and returns
control to the event loop until the network or disk is ready.

The inverse matters as much: a line with no `await` on it does not suspend. There is
no hidden yield anywhere in an `async` body, which is what makes §4's blocking
warning a rule a reader can actually check.

### 2.2 Function Coloring

`await` requires a state machine to pause, so it is legal only inside another
`async` function. `main` is the singular exception, acting as the root reactor entry
point.

`await` parses unconditionally wherever a unary expression is admissible; whether
the enclosing body licenses it is a static rule, which is why the diagnostic can
name the enclosing function rather than reporting a syntax error.

---

## 3. Spawning Concurrent Background Tasks

To fire off an `async` function concurrently without waiting for it, use `async` as
a **call-site prefix** (much as `go` works in Golang). This hands the state machine
to the reactor and immediately evaluates to a `chan T` (`channels.md` §2.2):

```vertex
// Fire and forget
async handleClient(var conn)

// Inline anonymous background routine
async func() async {
    await do_background_work()
}()

// Kick off now, wait later through the returned channel
let task = async fetch_data()
let result = await task.receive()
```

Three details in those six lines:

* **`var conn` is the transfer marker** (`ownership.md` §3). A spawned task outlives
  the statement that spawned it, so the connection must be moved into it, not shared
  with a caller that may drop it. There is no `.transfer()` method — `transfer` is a
  reserved name bound to nothing precisely so that `conn.transfer()` diagnoses
  against this rule.
* **The anonymous function carries its own `async` marker.** A function literal
  begins with all enclosing parse context cleared and re-establishes it from its own
  marker (grammar, *Function literals*), so an inner body that awaits must say
  `async` itself — it does not inherit the enclosing function's.
* **`async` followed by `.` is a namespace, not a prefix.** One token of lookahead
  decides: `async fetch_data()` is a launch, `async.Readable(fd)` is a member call
  (§8). Same treatment `gpu` and `npu` get.

---

## 4. When to Use `async`

**Rule:** mark a function `async` only if there is a code path where the kernel can
return "not ready."

| Call | Can the kernel delay? | Declared `async`? |
| --- | --- | --- |
| `conn.read(buf)` | Yes (no bytes arrived) | Yes |
| `listener.accept()` | Yes (no pending connection) | Yes |
| `conn.fd()` | No (struct field read) | No |
| `conn.setNoDelay(true)` | No (applied instantly) | No |
| `clock.now()` | No (reads monotonic counter) | No |

Marking a function that never suspends costs its callers the coloring for nothing.

**Warning on blocking.** Putting a synchronous blocking operation inside an `async`
function blocks the underlying OS thread and starves the event loop — every other
task on that reactor stops. The forms that do this:

* a heavy compute loop (hand it to `thread` instead),
* an OS sleep (use `await time.Sleep()`),
* a bare `ch.receive()` (`channels.md` §3.1 — use `await ch.receive()`),
* a `ch.send(v)` into a full buffer (`channels.md` §3.2 — there is no awaited send),
* a blocking syscall on a fd that was not opened non-blocking (§8.5).

---

## 5. `select{}` Multiplexing

`select{}` races several channel operations and proceeds with the first one ready.
It is specified in `channels.md` §4; two points bear repeating here because they are
easy to assume wrongly:

* **Every case is a channel receive.** `.receive()` or `.tryReceive()` on a
  `chan T`, and nothing else. A standalone `async` call is not admissible in case
  position — spawn it first with the `async` prefix (§3), which hands back a
  `chan T`, and put the `.receive()` on *that*.
* **`select{}` adds no waiting behaviour of its own.** It does not dispatch on a
  case's static type and does not race heterogeneous sources. Each case waits
  exactly as `.receive()` waits in the enclosing context — inside an `async`
  function, that means every case is `await`ed and the whole statement suspends the
  task.

```vertex
let connReadTask = async conn.read(buf)
let computeTask  = async compute()

select {
case let n, err = await connReadTask.receive():
    print(n)
case let v = await computeTask.receive():
    print(v)
}
```

Both cases above are awaited; mixing an awaited case with a bare one in a single
statement is illegal (`channels.md` §4.3).

---

## 6. Custom Reactors

Vertex defaults to `builtins/async` (wrapping `io_uring` / `kqueue` / `epoll`), but
does not force a runtime. A developer can write a dispatch loop against platform
primitives directly if the default reactor's scheduling policy needs tuning. §8
describes the exact seam this hangs off.

---

## 7. Language Comparison: Concurrency Models

| Feature | Golang | JavaScript | Rust | Vertex |
| --- | --- | --- | --- | --- |
| **Architecture** | Stackful (goroutines) | Event loop (promises) | Stackless state machine | Stackless state machine |
| **Spawning** | `go func()` | Implicit | `tokio::spawn()` | `async func()` |
| **Detection** | Runtime | Statically marked | Statically marked | Statically marked |
| **Contagious?** | No | Yes (`async`/`await`) | Yes (`async`/`.await`) | Yes (`async`/`await`) |
| **Memory / GC** | GC-managed heap | GC-managed heap | Zero-cost / no GC | Zero-cost / no GC |

Vertex aligns with the explicit readability of Rust and JavaScript while adopting the
lightweight kickoff ergonomics of Go.

### 7.1 Stackless Performance Gains

Stackless architectures compile suspension points into flat, discrete state machines
rather than pausing entire execution stacks. Two advantages over stackful models
(Go, OS threads):

1. **Lower memory footprint.** A stackful model must allocate a minimum stack block
   (Go's initial 2 KB per goroutine). A stackless one allocates only the exact byte
   width of the variables kept alive across the suspend point, allowing millions of
   concurrent waits in a fraction of the memory.
2. **Faster context switching.** Waking a stackless task is a direct function call
   branching on an integer state tag. Waking a stackful task requires swapping CPU
   registers and stack pointers, which carries higher latency.

### 7.2 The Golang Tradeoff (Why It Lacks Coloring)

Go famously avoids function coloring, at a strict architectural cost: **runtime
interception**. It achieves the colorless design by routing all network and file
operations through its own standard library, which silently intercepts blocking
syscalls and parks the goroutine on a hidden background event loop. Ergonomic, but
for systems programming the tradeoffs are severe:

* **No custom reactors.** You cannot build your own async flow from scratch or swap
  the event loop for a specialized `io_uring` or `kqueue` one.
* **Kernel lock-in.** Newer native kernel features, custom kernels, and bare metal
  all require porting the runtime scheduler.
* **The FFI choke point.** Native C or C++ that blocks (via cgo) breaks the
  illusion: the blocking call halts the underlying OS thread and starves the
  scheduler.

Vertex accepts coloring precisely to keep the runtime transparent and modular. By
exposing the state machine explicitly, it allows custom reactors (§6) and safe
C/C++ interop without hidden heuristics — which is the same argument §8.1 makes at
the level of a single primitive.

---

## 8. Low-Level FD Readiness — `builtins/async`

### 8.1 Philosophy

`async`/`await` (§1–§2) are the *language*'s suspension mechanism — they say "this
function may yield." They say nothing about *what* it waits on. That is a separate,
lower job: turning a kernel readiness fact into a suspension point. Vertex gives that
job exactly two functions and stops there deliberately — per §7.2, the alternative is
Go's path, where the readiness primitive is hidden inside a standard library you can
neither swap out nor build alongside.

```vertex
async.Readable(fd: int32) async -> string
async.Writable(fd: int32) async -> string
```

> The two lines above describe **call shapes**, not declarations. A `FunctionName` is
> an `identifier`, never a qualified one, so neither can be written as a `func` line
> in Vertex source; they are reached as members of the `async` namespace (§3). This
> is the same convention `memory.md` §0 uses for `new` and `delete`.

* **Scope: socket file descriptors.** Both suspend the calling task until the
  reactor observes `fd` as readable or writable, per the platform's poll primitive.
  They are the exact primitive a socket wrapper needs to turn an `EAGAIN` from a
  non-blocking syscall into a real suspension instead of a busy-loop or a blocked
  thread.
* **Not a socket type.** They take a bare `int32` — nothing about the fd's kind,
  protocol, or origin. They carry no opinion about what `fd` is; they only answer
  "is it ready." Any userspace wrapper (a `TcpConn`, a Unix domain socket, a raw
  `LibC.socket()` call never wrapped at all) reaches the same two functions the same
  way.
* **This is the seam custom reactors (§6) hang off.** A reactor swap means
  reimplementing these two against a different platform primitive — not rewriting
  every wrapper built on top of them.
* **Other fd kinds are future scope, not a different name.** Pipes, `eventfd`, TTYs,
  and regular files raise distinct readiness questions (§8.6) and are deliberately
  left out of this pass. When added, they will reuse `Readable`/`Writable` where the
  semantics genuinely match a socket's readiness model.

### 8.2 Signature

| Function | Blocks the OS thread? | Suspends the task? | Returns |
| --- | --- | --- | --- |
| `async.Readable(fd)` | No | Yes, until `fd` is readable | `string` — `""` on success, non-empty on reactor error (e.g. fd closed underneath the wait) |
| `async.Writable(fd)` | No | Yes, until `fd` is writable | `string` — same convention |

Both return a bare `string` rather than a tuple, because there is no value to hand
back — only success or failure (foundation §35.1). Check the string before trusting
that the wait resolved cleanly.

### 8.3 The Retry Pattern

These don't perform I/O themselves — they resolve only *when* a subsequent
non-blocking syscall is worth retrying. Every socket operation in Vertex follows the
same shape:

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

Try the syscall → on `EAGAIN`, `await` readiness → retry. That is the entire
mechanism; there is no hidden queuing or batching beneath it a wrapper author needs
to reason about.

### 8.4 Example — Socket Wrapper

```vertex
package net
build linux

import "libc"

struct TcpConn {
    fd: int32
}

class TcpListener {
    fd: int32
}

func (l: TcpListener) accept() async -> (TcpConn, string) {
    while true {
        var addr: LibC.SockAddrIn
        var len:  LibC.socklen_t = sizeof(LibC.SockAddrIn) as LibC.socklen_t

        let fd, err = LibC.accept(l.fd, addr, len)
        if err == "" {
            return TcpConn{fd: fd}, ""
        }
        if err != "EAGAIN" {
            var zero: TcpConn
            return zero, err
        }

        let werr = await async.Readable(l.fd)
        if werr != "" {
            var zero: TcpConn
            return zero, werr
        }
    }
}

func (c: TcpConn) read(buf: mut []byte) async -> (int32, string) {
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

Nothing in `TcpListener` / `TcpConn` is compiler-privileged — this is exactly the
code any developer writes to wrap a new fd kind. `async.Readable` / `Writable` are
the entire contract between userspace and the reactor.

`TcpConn` is a struct, so `TcpConn{fd: fd}` is a composite literal and the error
paths return `var zero: TcpConn`. Were it a class, both would change: a class is
constructed only by calling an initializer (foundation §27), and `var zero: TcpConn`
would be the only spelling available on the error path.

### 8.5 Precondition — Non-Blocking Fds

These make sense only against a fd opened non-blocking (e.g. `SOCK_NONBLOCK` at
`socket()` creation). Calling a blocking syscall and awaiting readiness afterward
doesn't compose — the syscall would already have blocked the thread before `EAGAIN`
ever had a chance to appear, which is §4's warning in its most concrete form.
Setting the flag at fd creation is the caller's responsibility; §8.1–§8.4 assume it
throughout.

### 8.6 Platform Note — Scope Boundary

`Readable`/`Writable` report real kernel readiness for sockets (and, by the same
underlying mechanism, pipes and other poll-able fds) on every reactor backend
(`epoll`, `kqueue`, `io_uring`). They are **not** currently specified for regular
files: `epoll`/`kqueue` report a file fd as always-ready, so `Readable(fd)` on one
returns immediately without a meaningful wait, while an `io_uring`-backed reactor
could in principle give it real completion semantics. Resolving that gap — either by
scoping file I/O to a `thread`-backed fallback or by giving files their own
readiness contract — is left for a future revision, not solved by this section.