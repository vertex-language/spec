# Vertex Native Interface

## 1. Concept

Native Interface is Vertex's unified model for reaching outside the managed
runtime. Every foreign target — C libraries, OS syscalls, GPU kernels, bare
metal interrupts, platform dispatch — is expressed through the same three-part
pattern:

1. **Import path** — tells the compiler which emission strategy to use
2. **Class declaration** — typed signature manifest bound to the import target
3. **Package** — wraps the class as a typed, importable export

The import path does all the routing. The class provides the contract.
The compiler enforces it.

---

## 2. The Three-Part Pattern

```swift
package libc                 // 3. package — the export
build linux
import "lib/c"               // 1. import path — emission strategy

class C : c {                // 2. class — signature manifest
    func fopen(path: *const char, mode: *const char) -> *void?
    func fwrite(ptr: *const void, size: uint64, count: uint64, stream: *void) -> uint64
    func fclose(stream: *void) -> int32
    func malloc(size: uint64) -> *void?
    func free(ptr: *void)
    func printf(fmt: *const char, ...) -> int32
}
```

**Rules:**

* The class name after `:` must match the final segment of the import path.
* Methods in a native class have no bodies — the backend owns the implementation.
* The package is the public boundary. Consumers import the package, not the
  raw class.
* One import path per file. One class per import target.

---

## 3. Import Path Protocol

The first path segment is the **emission prefix** — it routes the compiler
to the correct backend strategy. Everything after it identifies the specific
target.

```
"lib/*"          → linker — validate sigs at link time, emit linked call
"linux/*"        → inline syscall instruction, no linker
"darwin/*"       → platform dispatch (objc_msgSend / selectors)
"windows/*"      → vtable / COM slot dispatch
"gpu/*"          → kernel emission (PTX / shader IR)
"metal/*"        → bare metal (interrupts, ports, MMIO)
```

The path is the single source of truth for how the compiler emits.
No build tag modifiers, no extern qualifiers, no extra annotations needed.

---

## 4. Pointer Model

Vertex's pointer model maps directly to C. `*T` is a raw mutable pointer;
`*const T` is a read-only pointer. Both collapse to the same C pointer at
runtime — `const` is a compile-time annotation only.

| Vertex              | C equivalent  |
|---------------------|---------------|
| `name: *const T`    | `const T*`    |
| `name: *T`          | `T*`          |
| `name: *const void` | `const void*` |
| `name: *void`       | `void*`       |
| `name: *const char` | `const char*` |
| `name: *char`       | `char*`       |
| `name: *T?`         | nullable `T*` |
| `name: **T`         | `T**`         |

`let`/`var` controls whether the binding can be rebound.
`*const` controls whether the pointed-to data can be modified.
These are orthogonal — all four combinations are valid.

| Vertex               | C                | Binding | Data      |
|----------------------|------------------|---------|-----------|
| `let name: *const T` | `const T* const` | fixed   | read-only |
| `let name: *T`       | `T* const`       | fixed   | mutable   |
| `var name: *const T` | `const T*`       | rebind  | read-only |
| `var name: *T`       | `T*`             | rebind  | mutable   |

---

## 5. Passing Values to Native Functions

Because Vertex types lower directly to C types, most values reach native
functions without any conversion. The two mechanisms are direct passing and
`&` address-of.

**String literals** are `const char*` pointing into `.rodata`. They pass
directly to `*const char` parameters — no operator needed.

**`var` strings** (GString) expose a `.str` field of type `*const char` for
passing to C string parameters.

**`&value`** returns the raw address of any value as a typed pointer. Zero
cost — no allocation, no copy.

| What you have           | How to pass to native | Pointer type    |
|-------------------------|-----------------------|-----------------|
| string literal          | pass directly         | `*const char`   |
| `var s: string`         | `s.str`               | `*const char`   |
| `var x: int32`          | `&x`                  | `*int32`        |
| `var buf: [uint8]`      | `&buf` or `&buf[0]`   | `*uint8`        |
| `var p: Point`          | `&p`                  | `*Point`        |
| struct field `p.x`      | `&p.x`                | `*int32`        |

The returned pointer is valid only while the backing value is alive. Passing
it to a native call and then freeing the backing value is undefined behavior.
For ref-counted instances (`.new()`), retain the owning reference for the
full duration of any native call that holds the pointer.

---

## 6. Type Intrinsics

Type-level compile-time intrinsics are called on the type name, not an
instance. They resolve to constants at compile time — zero runtime cost.

```swift
SockaddrIn.sizeof()    // size of the type in bytes
SockaddrIn.alignof()   // alignment requirement in bytes
```

Instance-level intrinsic for byte length of arrays:

```swift
var vertices: [float] = [0.0, 0.5, 0.0]
vertices.byteSize()    // length * sizeof(element) — for C byte-count arguments
vertices.length        // element count
```

**Rules:**

* `.sizeof()` and `.alignof()` are only valid on type names, not instances.
* `.byteSize()` is only valid on array instances.
* All three resolve at compile time.

---

## 7. Type Aliases

```swift
type FILE   = *void
type size_t = uint64
```

**Rules:**

* `type` declares an alias — the two names are interchangeable.
* Aliases may appear at package level only, not inside functions or blocks.
* Aliases are resolved at compile time — no runtime representation.

---

## 8. Variadic Functions

```swift
class C : c {
    func printf(fmt: *const char, ...) -> int32
    func sprintf(buf: *char, fmt: *const char, ...) -> int32
    func open(path: *const char, flags: int32, ...) -> int32
}
```

**Rules:**

* `...` marks a variadic tail — zero or more additional arguments.
* `...` may only appear as the final parameter.
* `...` is only valid in native class declarations — Vertex functions may
  not be variadic.
* Arguments passed to `...` slots are not type-checked by the compiler.

---

## 9. Build Tags

Build tags are **pure platform selectors**. Emission strategy is fully
owned by the import path.

| Tag       | Meaning                          |
|-----------|----------------------------------|
| `linux`   | compile this file for Linux      |
| `darwin`  | compile this file for Darwin     |
| `windows` | compile this file for Windows    |
| `metal`   | compile this file for bare metal |

---

## 10. Multi-Platform Packages

Platform-specific files use a filename suffix matching the build tag. The
compiler selects the correct file for the target platform — no explicit
`build` tag required inside the file when the suffix is present.

```
tcp.vs          // compiled everywhere — shared types, constants, public API
tcp_linux.vs    // import "linux/syscalls"    — linux native binding
tcp_darwin.vs   // import "darwin/objc/..."   — darwin native binding
tcp_windows.vs  // import "windows/com/..."   — windows native binding
```

---

## 11. Instances

Native class instances are **zero-size compile-time dispatch surfaces**.
The backend removes them entirely — no allocation, no runtime overhead.

```swift
var c = libc.C()          // zero bytes at runtime
c.printf("hello\n")       // emits direct linked call — instance vanishes
```

The instance exists only to give the developer a consistent, typed call
surface that matches every other Vertex object.

---

## 12. Strategies

### 12.1 `lib/` — Linked

```swift
package libc
build linux
import "lib/c"

type FILE = *void

class C : c {
    func fopen(path: *const char, mode: *const char) -> FILE?
    func fwrite(ptr: *const void, size: uint64, count: uint64, stream: FILE) -> uint64
    func fread(ptr: *void, size: uint64, count: uint64, stream: FILE) -> uint64
    func fclose(stream: FILE) -> int32
    func malloc(size: uint64) -> *void?
    func free(ptr: *void)
    func printf(fmt: *const char, ...) -> int32
}
```

Compiler: fires the linker, validates signatures against the library at link
time. Emits a standard linked call at each call site.

Usage:
```swift
var c = libc.C()
let f = c.fopen("/tmp/out.bin", "wb")
defer c.fclose(f)

var data = [uint8](repeating: 0xFF, count: 256)
c.fwrite(&data, 1, data.byteSize(), f)
c.printf("wrote %d bytes\n", data.length)
```

---

### 12.2 `linux/` — Syscall

```swift
package syscall2
build linux
import "linux/syscalls"

class Syscalls : syscalls {
    func open(path: *const char, flags: int32, mode: uint32) -> int32
    func openat(dirfd: int32, path: *const char, flags: int32, mode: uint32) -> int32
    func openat2(dirfd: int32, path: *const char, how: *const void, size: uint32) -> int32
    func close(fd: int32) -> int32
    func close_range(first: uint32, last: uint32, flags: uint32) -> int32
    func read(fd: int32, buf: *void, count: uint64) -> int32
    func write(fd: int32, buf: *const void, count: uint64) -> int32
}
```

Compiler: resolves syscall number from method name (`open` → `NR_open`),
determines arg count, emits inline syscall instruction. No linker involved.

Usage:
```swift
var s = syscall2.Syscalls()
let fd = s.open("/tmp/out", O_WRONLY, 0o644)
defer s.close(fd)
s.write(fd, &data, data.byteSize())
```

---

### 12.3 `darwin/` — Platform Dispatch

```swift
package foundation
build darwin
import "darwin/objc/foundation"

class NSString : foundation {
    func length(s: NSString) -> int32
    func UTF8String(s: NSString) -> *const char
    func isEqualToString(s: NSString, other: NSString) -> bool
    func substringFromIndex(s: NSString, from: int32) -> NSString
    func stringWithUTF8String(str: *const char) -> NSString?
}
```

Compiler: emits `objc_msgSend` with selector derived from method name.
First typed param is the receiver. No receiver = class-side method.

Usage:
```swift
var ns = foundation.NSString()
let str = ns.stringWithUTF8String("hello")
let len = ns.length(str)
```

---

### 12.4 `windows/` — COM / Vtable

```swift
package d3d11
build windows
import "windows/com/d3d11"

class IUnknown : d3d11 {
    func QueryInterface(obj: IUnknown, riid: *const void, ppv: *void) -> int32
    func AddRef(obj: IUnknown) -> uint32
    func Release(obj: IUnknown) -> uint32
}

class ID3D11Device : IUnknown {
    func CreateBuffer(
        d: ID3D11Device,
        desc: *const void,
        init: *const void,
        ppBuffer: **void) -> int32
    func CreateTexture2D(
        d: ID3D11Device,
        desc: *const void,
        init: *const void,
        ppTexture: **void) -> int32
}
```

Compiler: emits vtable slot dispatch. Declaration order = slot order.
Parent class slots are prepended — child methods begin at `len(parent)`.
Lifetime managed via `AddRef` / `Release`.

---

### 12.5 `gpu/` — Kernel Emission

```swift
package cuda2
build linux
import "gpu/cuda"

class Cuda : cuda {
    let threadIdx: (x: uint32, y: uint32, z: uint32)
    let blockIdx:  (x: uint32, y: uint32, z: uint32)
    let blockDim:  (x: uint32, y: uint32, z: uint32)
    let gridDim:   (x: uint32, y: uint32, z: uint32)

    func syncThreads()
    func syncWarp(mask: uint32)
    func atomicAdd(addr: *float, val: float) -> float
    func atomicAdd(addr: *int32, val: int32) -> int32
    func fmaf(a: float, b: float, c: float) -> float
    func rsqrtf(x: float) -> float
}
```

Compiler: emits PTX. `threadIdx` → `%tid` register reads. `syncThreads()`
→ `bar.sync`. `fmaf` → `fma.rn.f32`. Instance removed entirely.

GPU functions use the `gpu` qualifier between the parameter list and the
return type. Shared memory uses the `shared` storage qualifier — the backend
allocates in `.shared` PTX memory space. The call site uses `.dispatch()`.

```swift
let TILE: int32 = 16

func matMul(a: *const float, b: *const float, out: *float, n: int32) gpu {
    var c = cuda2.Cuda()

    shared var tileA = [float](TILE * TILE)
    shared var tileB = [float](TILE * TILE)

    let tx  = c.threadIdx.x
    let ty  = c.threadIdx.y
    let row = c.blockIdx.y * TILE + ty
    let col = c.blockIdx.x * TILE + tx

    var sum: float = 0.0

    for t in 0 ..< n / TILE {
        tileA[ty * TILE + tx] = a[row * n + t * TILE + tx]
        tileB[ty * TILE + tx] = b[(t * TILE + ty) * n + col]
        c.syncThreads()

        for k in 0 ..< TILE {
            sum = c.fmaf(tileA[ty * TILE + k], tileB[k * TILE + tx], sum)
        }
        c.syncThreads()
    }

    out[row * n + col] = sum
}

// call site — a, b, result are device memory pointers
matMul(a: devA, b: devB, out: devResult, n: 1024).dispatch()
```

---

### 12.6 `metal/` — Bare Metal

```swift
package bios
build metal
import "metal/int10h"

class Int10h : int10h {
    func set_video_mode(mode: uint8)
    func set_cursor_size(start_line: uint8, end_line: uint8)
    func set_cursor_pos(page: uint8, row: uint8, col: uint8)
    func get_cursor_pos(
        page: uint8,
        row: *uint8, col: *uint8,
        start: *uint8, end: *uint8)
    func scroll_up(
        lines: uint8, attr: uint8,
        top: uint8, left: uint8, bottom: uint8, right: uint8)
    func scroll_down(
        lines: uint8, attr: uint8,
        top: uint8, left: uint8, bottom: uint8, right: uint8)
    func read_char_attr(page: uint8, char: *uint8, attr: *uint8)
    func write_char_attr(page: uint8, char: uint8, attr: uint8, count: uint16)
    func write_char(page: uint8, char: uint8, count: uint16)
    func write_tty(char: uint8, page: uint8, color: uint8)
    func get_video_mode(mode: *uint8, cols: *uint8, page: *uint8)
    func write_string(
        page: uint8, attr: uint8, flags: uint8,
        row: uint8, col: uint8, str: *const char, len: uint16)
    func write_pixel(page: uint8, color: uint8, col: uint16, row: uint16)
    func read_pixel(page: uint8, col: uint16, row: uint16) -> uint8
    func set_palette(palette_id: uint8, color: uint8)
    func set_active_page(page: uint8)
}
```

Compiler: emits hardware interrupt instruction with register mapping
derived from the interrupt number in the path (`int10h` → `INT 10h`).
No linker, no runtime.

Usage:
```swift
var b = bios.Int10h()
b.set_video_mode(0x03)
b.set_cursor_pos(0, 0, 0)
b.write_tty(0x41, 0, 0x07)
```

---

## 13. Rules Summary

| Rule | Detail |
|------|--------|
| Import prefix routes emission | `lib/` links, `linux/` syscalls, `gpu/` PTX, etc. |
| Class name matches import tail | `import "lib/c"` → `class C : c` |
| Methods have no bodies | backend owns the implementation |
| Instances are zero-size | removed entirely by the backend |
| Build tags select platform only | emission strategy lives in the import path |
| Package is the export boundary | consumers import the package, not the class |
| Sigs enforced at compile time | mismatch = error before anything links or runs |
| Variadic `...` in native only | Vertex functions may not be variadic |
| String literals pass directly | `const char*` — no conversion needed |
| `&value` for address-of | zero-cost; pointer valid only while value is alive |
| GPU call site uses `.dispatch()` | consistent with postfix execution model |

---

## 14. Postfix Summary

| Postfix       | Meaning                                 |
|---------------|-----------------------------------------|
| `.sizeof()`   | compile-time size of type in bytes      |
| `.alignof()`  | compile-time alignment of type in bytes |
| `.byteSize()` | runtime byte length of array instance   |
| `.dispatch()` | execute GPU kernel, return result       |