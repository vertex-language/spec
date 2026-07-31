# Vertex Language Grammar

## Specification — Abstract Interfaces

---

## 0. The Abstract Interface Philosophy

Foreign interop in Vertex is a **structural contract**. You define the shape of the external library using native Vertex types inside a `declare framework` or `declare module` block, and the compiler's backend automatically emits the correct calling convention based on the file's `build` tag (e.g., C standard calling conventions on Windows, Objective-C message passing on Darwin, or a JS bundle's call/property-access shape) — refined, where needed, by an explicit variant tag (§4.4).

Interop is always handled in **two layers**:

1. **The Abstract Interface** (§4, §6) — A declaration of the foreign symbols and their structural shapes inside a `declare framework` or `declare module` block. This is an audit boundary and a link edge, **not** where memory is managed, and **not** where foreign layout is described. It describes *what the outside world exposes*, never *how it's laid out* — every declaration is a call shape (arguments in, values out), never a struct-layout claim about the foreign side.
2. **The Safe Wrapper** (§7) — Ordinary Vertex classes the developer writes on top of the abstract interface. This is where ownership lives: the wrapper holds the handle as a field, and the wrapper's `deinit` (or `shared` discipline) frees or releases the resource.

**Consequence — no ownership keywords in the interface.** `var` (and any consume/transfer marking) is **banned** from an abstract interface declaration. Ownership is a fact about the *wrapper's field*, decided in the wrapper, not a decoration on an external stub.

**Consequence — exactly what is written is what is linked.** An abstract interface contains only declarations that correspond to actual entry points in the foreign library. There are no marker declarations, no visibility modifiers, no remapping clauses, and no bodies.

**Consequence — layout never crosses the boundary.** Because the interface only ever describes opaque handles (`abstract`, §2), primitives, and call shapes, the question "which C++ ABI, exactly?" never has to be answered by the *type system* — only, occasionally, by the *linker/codegen*, which is what §4.4's variant tag is for. If a foreign signature ever needs a non-opaque, layout-dependent foreign type (a raw `std::string`, a C++ template instance) to cross the boundary directly, that is out of scope for this layer — wrap it behind an opaque handle and expose accessors instead.

---

## 1. Linkage and ABI (Build Tags)

Vertex relies strictly on **build tags** to determine the base Application Binary Interface (ABI) family of an external declaration. A `declare framework` or `declare module` block is only valid in a file that explicitly declares a target platform. This prevents linker errors and cross-compilation drift.

```vertex
package win32
build windows     // Tells the backend to expect a native Windows DLL (C-ABI)

```

```vertex
package dom
build js          // Tells the backend this maps to a JavaScript environment

```

The build tag dictates the underlying object model family (C, WASM, Darwin frameworks, or JS modules). The `declare framework`/`declare module` block itself requires no file paths or slashes — only the string name of the module or framework that the linker or bundler will resolve.

**Build tag picks the family; the block keyword and the class rules (§4) pick the convention within it; §4.4's variant tag is the only remaining escape hatch, and only for the minority case where the family alone is ambiguous.**

---

## 2. Foreign Handles — `abstract`

```vertex
type SDL_Window   = abstract
type NSView       = abstract
type WebSocket    = abstract
type MessageEvent = abstract

```

An `abstract` type is a foreign resource Vertex holds by an opaque word: its interior belongs to the foreign environment and is invisible to the Vertex type system. It makes a statement about **knowledge**, not about layout — "structure exists, but Vertex declines to model it." This is the same discipline that makes §0's "layout never crosses the boundary" consequence hold: nothing about a C++ vtable's shape, an ObjC ivar layout, or a COM interface's memory model is ever encoded in Vertex types — only the ability to call through the handle is.

**Copy does not exist for `abstract`.** An abstract handle can only be **accessed** or **moved**. It is not a `unique T` and must not be spelled as one.

**Zero value.** An abstract type has a zeroed representation, but it is legal **only** as an error-path value paired with a non-empty error string (the boundary tuple, §3). There is no comparable `nil` for abstract handles.

Each abstract alias is a distinct **nominal** type. `SDL_Window` and `NSView` do not unify and cannot be assigned to one another.

---

## 3. The Boundary Tuple (Fallibility & Null/Undefined)

Foreign functions do not throw exceptions into Vertex. Functions that can fail — a C-style function returning a potentially `NULL` pointer, or a JS API that can throw or return `undefined` — map to Vertex's standard Foundation error tuple (`-> (Value, string)`).

| Foreign Behavior | Vertex Interface Shape |
| --- | --- |
| Returns `T*` (Nullable) | `-> (T, string)` |
| Returns `status` and `T**` out-param | `-> (int32, T, string)` |
| JS call that may throw / return `undefined` | `-> (T, string)` |

* **On Success:** The handle receives a valid value, and the string is empty (`""`).
* **On Failure:** The handle is zeroed, and the runtime populates the string with a failure message.

---

## 4. Structural ABI Typing

Vertex has **two** block keywords for describing a foreign library, distinguished by how the foreign side is packaged and, by convention, what calling discipline it implies. Both act as a linkage boundary, not a namespace — symbols declared inside either are injected into the file's current Vertex package.

### 4.1 `declare framework` — Bundled, Message-Passing Libraries

```vertex
declare framework "AppKit" {
    class NSWindow {
        init func() -> NSWindow
        func center()
    }
}
```

* `declare framework` names a platform-bundled, versioned library — the Darwin sense of "framework" (a `.framework` bundle, a system dylib with an associated interface). On Darwin, a `class` inside a `declare framework` block is **always** lowered to Objective-C message passing (`objc_msgSend`). There is exactly one convention here, always the same, with no variant to select — this is why it is safe to leave silent: unlike C++ (§4.2), ObjC message passing does not fork by compiler, standard library, or flag.
* `declare framework` is only meaningful where the platform has a first-class notion of a bundled, dynamically-resolved library (Darwin today). Using it under a `build` tag with no such concept (`windows`, `linux`, `js`) is a compile error.

### 4.2 `declare module` — Everything Else (Flat C, C++, JS, DLLs)

An API with no object lifecycle (like standard C libraries) is mapped by dropping the function declarations directly inside a `declare module` block — the **flat namespace** form:

```vertex
package sdl2
build windows // or linux, etc.

type SDL_Window = abstract

declare module "sdl2" {
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
}

```

A `declare module` block may also nest a `class`, for an interface representing a real, instantiable object. The compiler infers the object model based on the presence of `init func` declarations:

```vertex
package dom
build js

type WebSocket = abstract

declare module "websocket" {
    class WebSocket {
        init func(url: string) -> WebSocket
        init func withProtocols(url: string, protocols: string) -> WebSocket
        func send(data: string)
    }
}

```

* `init` is a **prefix modifier** on `func`, not a function name. It marks the declaration as a constructor.
* **Unnamed — `init func() -> Self`.** What bare `Type(...)` construction resolves to.
* **Named — `init func someName(...) -> Self`.** What `Type.someName(...)` resolves to.

**Default convention by build tag, when `declare module` (not `declare framework`) contains a `class`:**

| `build` | Default `class` convention |
| --- | --- |
| `darwin` | C++ (Itanium ABI, exceptions on) — a non-framework Darwin library is assumed to be a C++ static/dynamic library, since ObjC access on Darwin goes through `declare framework` instead |
| `linux` | C++ (Itanium ABI, exceptions on) |
| `windows` | Raw C++ vtable call (not COM) |
| `js` | Ordinary JS object/class call shape (§4.2's WebSocket example) |

These defaults exist precisely because `declare module` is the "everything that isn't a bundled framework" bucket, and C++ is overwhelmingly the common case for a non-framework, class-shaped native library. Where the default convention is wrong for a given library — a different C++ ABI, exceptions off, or Windows COM instead of a raw vtable — use the variant tag (§4.4) to override it explicitly rather than silently guessing.

### 4.3 Illegal Forms

```vertex
declare framework "AppKit" {
    class Bad {
        private init func() -> Bad        // error: visibility modifiers banned
        init func() -> Bad                // error: duplicate unnamed initializer
        init func broken(x: int32) -> int32 // error: must return enclosing type
    }

    func SDL_Init() -> int32 {
        return 0                          // error: declarations cannot have bodies
    }
}

declare framework["windows", "com"] "SomeLib" {  // error: `declare framework` takes
    class Foo { }                                //        no variant tag — framework
}                                                 //        linkage is always objc

declare module "libfoo" {
    class Foo {
        std_string: string                // error: no fields — a declare block
    }                                      //        describes call shape only,
                                            //        never foreign-side layout
}

```

### 4.4 Variant Tags — Overriding the Default Convention

Most libraries need nothing beyond §4.1/§4.2's defaults. For the minority case where the default is wrong — a specific C++ ABI variant, exceptions compiled out, or a Windows COM interface instead of a raw vtable — attach a **variant tag** to `declare module` using the same bracketed parameter slot every other part of the grammar already uses for compile-time configuration (compare `chan[float32]`, foundation.md §21's `[N]T`):

```vertex
declare module["windows", "com"] "some.dll" {
    class ISomeInterface {
        func Release() -> uint32
    }
}

```

```vertex
declare module["cxx", "no-exceptions"] "libfoo" {
    class Foo {
        init func() -> Foo
        func compute(x: int32) -> int32
    }
}

```

* The bracket holds a fixed, closed set of string tags — not an open attribute map. Illegal or contradictory combinations (e.g. `["com"]` under `build linux`, or `["windows", "com"]` on a `declare framework` block) are compile errors, checked against the file's `build` tag the same way every other cross-check in this document is.
* Omitting the bracket entirely (plain `declare module "name" { }`) always means "use §4.2's default table for this build tag." The bracket exists to *narrow*, never to introduce a capability unavailable by default.
* `declare framework` never takes a variant tag (§4.3) — bundled ObjC linkage has exactly one convention, by design (§4.1).

---

## 5. Non-Resource Pointer Shapes

| Foreign Shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*` (writable scalar out-param) | `mut T` |
| `T*` + length | `[]T` (read) / `mut []T` (write) |
| `T*` held and strided manually | `typed_ptr T` — raw pointer (last resort) |
| JS property read / static field | ordinary bodyless `func` returning the field's type |

---

## 6. The Abstract Interface Examples

```vertex
package appkit
build darwin

type NSWindow = abstract
type Rect = abstract // assuming defined elsewhere

declare framework "AppKit" {
    class NSWindow {
        init func() -> NSWindow
        init func initWithContentRect(
            contentRect: Rect, styleMask: uint64, backing: uint64, defer: bool
        ) -> NSWindow
        func center()
    }
}

```

```vertex
package comdlg
build windows

type ISomeInterface = abstract

declare module["windows", "com"] "some.dll" {
    class ISomeInterface {
        func Release() -> uint32
    }
}

```

---

## 7. Wrapper Classes — the Safe Layer

RAII, no inheritance. Each wrapper owns its handle and frees or releases it in `deinit`. This is the layer the developer writes.

### 7.1 A Flat C Wrapper

```vertex
package windowing
// Imports the sdl2 package containing the `declare module` block
import "sdl2" 

class Window {
    handle: sdl2.SDL_Window
}

func (w: Window) init(title: string) {
    let handle, err = sdl2.SDL_CreateWindow(title, 0, 0, 800, 600, 2)
    if err != "" {
        panic("Failed to create window: " + err)
    }
    w.handle = handle
}

func (w: Window) deinit() {
    sdl2.SDL_DestroyWindow(w.handle)
}

```

### 7.2 A JS Wrapper

```vertex
package net
import "dom" // Imports the package holding the JS WebSocket declarations

class Socket {
    handle: dom.WebSocket
}

func (s: Socket) init(url: string) {
    // Resolves to unnamed `init func(url: string)`
    s.handle = dom.WebSocket(url: url)
}

func (s: Socket) initWithProtocols(url: string, protocols: string) {
    // Resolves to named `init func withProtocols(...)`
    s.handle = dom.WebSocket.withProtocols(url: url, protocols: protocols)
}

func (s: Socket) deinit() {
    s.handle.close()
}

func (s: mut Socket) sendText(msg: string) {
    s.handle.send(msg)
}

```

### 7.3 A Framework (ObjC) Wrapper

```vertex
package windowing
import "appkit"

class Window {
    handle: appkit.NSWindow
}

func (w: Window) init() {
    w.handle = appkit.NSWindow()
    w.handle.center()
}

```

---

## 8. Callbacks Across the Boundary

A boundary `func(...)` is a bare function pointer: one word, no environment. Only a **non-capturing** function converts across an abstract interface boundary. Capturing closures are rejected at compile time because the foreign side has nowhere to stash the closure's environment.