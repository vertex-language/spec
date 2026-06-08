# builtin — Lowest Compiled Layer

---

## TODO — Requires Platform Libs

These packages cannot be written until `lib/linux/*`, `lib/darwin/*`,
and `lib/windows/*` exist. They are planned, required, and go here —
not in `core/` — because the Lowerer will hardcode them exactly as it
hardcodes `maps_new` today.

Do not implement any of these against `intrinsics/*` only.
A partial version with the wrong contract is worse than no version.

---

### builtin/mem — grow support

The current `builtin/mem` is a fixed-size arena.
It works for freestanding and for programs with bounded allocation.
It does not work for hosted programs with spiky or unbounded needs.

Once platform libs exist, `init` gains a grow callback:

```vertex
func init(
    region:  *uint8,
    size:    uint64,
    grow_fn: func(min_bytes: uint64) -> (*uint8, uint64)?
)
```

`builtin/mem` itself stays intrinsics-only and never imports a platform
package. The grow callback is provided at startup by `core/linux`,
`core/darwin`, or `core/windows` — each of which calls `mmap`,
`vm_allocate`, or `VirtualAlloc` respectively.

The allocator calls `grow_fn` when the arena is exhausted and maps the
new region into the free list. No other change to the public API.

Also unlocked once platform libs exist:

- `madvise(MADV_FREE)` / `VirtualFree(MEM_DECOMMIT)` — return physical
  pages to the OS after large frees without releasing virtual address space
- `mprotect` / `VirtualProtect` — guard pages in debug builds; a buffer
  overrun becomes a hard fault instead of silent corruption
- Huge page opt-in — `mmap(MAP_HUGETLB)` / `VirtualAlloc(MEM_LARGE_PAGES)`
  for large working sets

---

### builtin/threads

Threads require the OS scheduler.

```
Linux   →  clone3
Darwin  →  pthread_create
Windows →  CreateThread
```

The Lowerer will emit `b.Call("threads_spawn", ...)` for `go` statements
once this package exists. The public API surface is small — spawn, join,
detach, thread-local storage base. The blocking primitives (mutex, condvar)
live here too since futex / `__ulock_wait` / `WaitOnAddress` are needed.

Depends on: `lib/linux/syscall`, `lib/darwin/syscall`, `lib/windows/syscall`

---

### builtin/channels

A channel without blocking is a different contract and the wrong thing
to ship. Blocking requires the OS to park and wake a thread:

```
Linux   →  futex(FUTEX_WAIT / FUTEX_WAKE)
Darwin  →  __ulock_wait / __ulock_wake
Windows →  WaitOnAddress / WakeByAddressSingle
```

The lock-free ring buffer mechanics (`intrinsics/atomic` cursors) are
ready now. Only the blocking layer is gated on platform libs.
Do not ship a ring buffer as `builtin/channels` without the blocking
layer — name it something else if it is needed in the interim.

Depends on: `builtin/threads`, platform syscall libs

---

### builtin/async

`async` / `.await()` lowers to `tasks.wait` which wraps threads.
Cannot exist until `builtin/threads` exists.

A stackful coroutine could be pure machine code (save registers, swap
stack pointers, restore) and could in principle live in `builtin/*` now.
Vertex's async model is not a coroutine model at this layer — it is a
thread model. A freestanding cooperative scheduler, if ever needed,
belongs in `core/` as an explicit opt-in, not here.

Depends on: `builtin/threads`

---

### builtin/process

Process creation is entirely an OS concept.
`fork` / `execve` / `CreateProcess` — all syscalls, all platform.
No part of this package can be written against `intrinsics/*` alone.

Depends on: `lib/linux/syscall`, `lib/darwin/syscall`, `lib/windows/syscall`

---

## TODO — Full Map

```
builtin/                    status
  mem         (grow)        needs lib/linux · lib/darwin · lib/windows
  threads                   needs lib/linux · lib/darwin · lib/windows
  channels                  needs builtin/threads
  async                     needs builtin/threads
  process                   needs lib/linux · lib/darwin · lib/windows
```

---

## What This Layer Is

`builtin/*` is the lowest layer of real compiled Vertex.
These packages produce actual symbols in the binary.
They depend only on `intrinsics/*` — nothing above them.

The Lowerer has `builtin/*` hardcoded as its emit target.
When it erases syntax sugar it emits `b.Call("maps_new", ...)` and stops.
It does not reach into `core/` or any platform package.

User code never imports `builtin/*` directly.
The Lowerer is the only consumer.

---

## The Stack

```
intrinsics/*     machine instructions — no symbols, always inlined
      ↑ used by
builtin/*        real symbols — depends only on intrinsics/*
      ↑ hardcoded by
Lowerer          erases syntax sugar into builtin/* calls
      ↑
user code        never sees builtin/* directly
```

---

## Compiler Behavior

A package tagged `build builtin`:

- Is compiled after `intrinsics/*`, before `core/*`
- Produces real symbols in the binary
- May only import `intrinsics/*` or other `builtin/*` packages
- Importing anything from `core/*` or a platform package is a hard
  compiler error

---

## builtin/mem

Every other `builtin/*` package needs heap allocation.
`builtin/mem` is the allocator — it sits at the base of the layer
and has only `intrinsics/memory` and `intrinsics/atomic` beneath it.

The allocator manages a region of raw memory. How that region is
obtained is not `builtin/mem`'s concern — it is provided by the
initializer at startup. In hosted mode the runtime supplies it.
In freestanding the kernel supplies it. `builtin/mem` operates
identically in both cases.

```vertex
build builtin
package mem

import "intrinsics/memory"
import "intrinsics/atomic"

// called once at startup — hands the allocator its arena
func init(region: *uint8, size: uint64)

func alloc  (size: uint64) -> *uint8
func realloc(ptr: *uint8, old_size: uint64, new_size: uint64) -> *uint8
func free   (ptr: *uint8, size: uint64)
```

`intrinsics/memory.zero` initializes freed blocks.
`intrinsics/atomic` guards the free-list head under concurrent access
if the platform permits it — in single-core freestanding it reduces
to plain loads and stores.

This is the v1 interface. See TODO above for the grow-callback upgrade.

---

## builtin/arrays

Backing type for all growable `[T]` syntax and dynamic array literals.

```vertex
build builtin
package arrays

import "intrinsics/memory"
import "builtin/mem"

struct Array {
    data:   *uint8
    len:    uint64
    cap:    uint64
    stride: uint64
}

// construction / destruction
func new             (stride: uint64) -> Array
func new_cap         (stride: uint64, cap: uint64) -> Array
func free            (a: *Array)

// mutation
func push            (a: *Array, val: *const uint8)
func pop             (a: *Array) -> *uint8
func unshift         (a: *Array, val: *const uint8)
func shift           (a: *Array) -> *uint8
func remove_at       (a: *Array, index: uint64)
func fill            (a: *Array, val: uint8)

// access
func get             (a: *const Array, index: uint64) -> *uint8
func set             (a: *Array, index: uint64, val: *const uint8)

// search
func index_of        (a: *const Array, val: *const uint8,
                      eq: func(*const uint8, *const uint8) -> bool) -> int64
func find            (a: *const Array,
                      pred: func(*const uint8) -> bool) -> *uint8?

// in-place — no allocation
func sort            (a: *Array, cmp: func(*const uint8, *const uint8) -> int32)
func reverse         (a: *Array)

// allocating — caller must free result
func map_fn          (a: *const Array, stride_out: uint64,
                      fn: func(*const uint8) -> *uint8) -> Array
func filter          (a: *const Array, pred: func(*const uint8) -> bool) -> Array
func slice           (a: *const Array, from: uint64, to: uint64) -> Array
func concat          (a: *const Array, b: *const Array) -> Array
```

**Intrinsics used:**

`intrinsics/memory.copy` — buffer copies on growth and `concat`
`intrinsics/memory.move` — `remove_at` shifts trailing elements
`intrinsics/memory.zero` — wipes released slots on `pop`/`shift`
`builtin/mem.realloc`    — backing buffer growth

Growth doubles capacity. `new_cap` pre-allocates when the final
size is known at construction time.

---

## builtin/strings

Backing type for mutable string values bound to `var`.
Immutable `let` strings skip this package entirely —
they are `.rodata` pointer and length, nothing allocated.

```vertex
build builtin
package strings

import "intrinsics/memory"
import "builtin/mem"

struct String {
    data: *uint8
    len:  uint64
    cap:  uint64
}

// construction / destruction
func new        (src: *const uint8, len: uint64) -> String
func free       (s: *String)

// mutation
func append_byte(s: *String, b: uint8)
func append_str (s: *String, src: *const uint8, len: uint64)
func clear      (s: *String)
func truncate   (s: *String, len: uint64)

// comparison / hashing — used by builtin/maps for string-keyed dicts
func equal      (a: *const String, b: *const String) -> bool
func hash       (s: *const String) -> uint64
```

**Intrinsics used:**

`intrinsics/memory.copy` — `new` copies from `.rodata`, `append_str`
`intrinsics/memory.zero` — `clear` wipes the buffer
`builtin/mem.realloc`    — growth on append

`strings.hash` is a pure integer computation over bytes —
no intrinsic, no library call.

---

## builtin/maps

Backing type for all `map[K, V]` syntax and dict literals.

```vertex
build builtin
package maps

import "intrinsics/memory"
import "intrinsics/bit"
import "builtin/mem"

struct Map {
    buckets: *uint8
    len:     uint64
    cap:     uint64
    hash_fn: func(*uint8, uint64) -> uint64
    eq_fn:   func(*uint8, *uint8) -> bool
}

struct Iter {
    var map: *Map
    var pos: uint64
}

// construction / destruction
func new   (hash_fn: func(*uint8, uint64) -> uint64,
            eq_fn:   func(*uint8, *uint8) -> bool) -> Map
func free  (m: *Map)

// mutation
func insert(m: *Map, key: *const uint8, val: *const uint8)
func remove(m: *Map, key: *const uint8) -> bool

// lookup
func get   (m: *const Map, key: *const uint8) -> *uint8?

// iteration
func iter  (m: *Map) -> Iter
func next  (it: *Iter) -> (key: *uint8, val: *uint8)?

// built-in key helpers — used by Lowerer for string-keyed dicts
func str_hash (key: *const uint8, seed: uint64) -> uint64
func str_equal(a: *const uint8, b: *const uint8) -> bool
```

**Intrinsics used:**

`intrinsics/bit.clz64`   — next power-of-two capacity on grow
`intrinsics/memory.zero` — bucket initialization on alloc and clear
`intrinsics/memory.copy` — rehash copies entries into new bucket array
`builtin/mem.alloc`      — initial bucket array
`builtin/mem.realloc`    — rehash

Capacity is always a power of two. `bit.clz64` computes the next
power of two in a single instruction instead of a loop.
The load factor threshold triggers rehash at 75% occupancy.

---

## Full Map

```
builtin/                    status
  mem                       ready — fixed arena, grow pending
  arrays                    ready
  strings                   ready
  maps                      ready

  threads                   TODO — needs platform libs
  channels                  TODO — needs builtin/threads
  async                     TODO — needs builtin/threads
  process                   TODO — needs platform libs
```

Every package in the ready column depends only on `intrinsics/*` and
other `builtin/*` packages. No OS. No firmware. No linked library.