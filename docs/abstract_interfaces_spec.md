# Vertex Language Grammar

## Specification — Abstract Interfaces

---

## 0. The Abstract Interface Philosophy

Foreign interop in Vertex is not just a C-header mapping; it is a **structural contract**. You define the shape of the external library using native Vertex types, and the compiler's backend automatically emits the correct calling convention — whether that is C standard calling conventions, Objective-C message passing, C++ mangling, or a JS bundle's call/property-access shape.

Interop is always handled in **two layers**:

1. **The Abstract Interface** (§4, §6) — A declaration of the foreign symbols and their structural shapes. This is an audit boundary and a link edge, **not** where memory is managed. It describes *what the outside world exposes*.
2. **The Safe Wrapper** (§7) — Ordinary Vertex classes the developer writes on top of the abstract interface. This is where ownership lives: the wrapper holds the handle as a field, and the wrapper's `deinit` (or `shared` discipline) frees or releases the resource.

The vocabulary is deliberately uniform across the two layers: an abstract *interface* declares functions whose bodies are withheld; an abstract *type* (§2) declares a value whose interior is withheld. Both are resolved by the same backend knowledge of the import path's ABI, and both mean the same thing — *structure exists on the foreign side; Vertex declines to model it.*

**Consequence — no ownership keywords in the interface.** `var` (and any consume/transfer marking) is **banned** from an abstract interface declaration. Ownership is a fact about the *wrapper's field*, decided in the wrapper, not a decoration on an external stub.

**Consequence — every line is a real foreign symbol.** An abstract interface contains only declarations that correspond to actual entry points in the foreign library. There are no marker declarations, no visibility modifiers, and no bodies. If a line appears in an interface, the linker (or, for a JS target, the bundler/runtime) can point at it.

**Consequence — the Vertex name is the name.** There is no remapping clause anywhere in an abstract interface. Whatever you write as the function name and parameter labels is what the compiler uses, both to generate the call site and to derive the foreign entry point (mangled symbol, selector, or property/method name, per target). If a foreign label collides with a Vertex keyword — `defer`, say — it's still just a label (§5) and is written exactly as it appears in the foreign library.

---

## 1. Library Linking

The compiler traces the `import` path to determine the underlying ABI of the library — a standard flat library, an Apple framework, a WASM import namespace, or a JS global/module.

```vertex
import "lib/sdl2"
import "darwin/framework/AppKit"
import "wasm/wasi_snapshot_preview1"
import "js/websocket"
```

A `js/...` path tells the backend the target is a JS bundle: declared calls lower to plain method calls or property reads on the corresponding JS object graph, not a C ABI or message send. Nothing else about the grammar below changes based on target — the same `class : lib { ... }` shape describes C, Objective-C, C++, WASM, and JS foreign surfaces alike.

The ABI classification recorded here does one additional job later: it decides whether an abstract type minted from this library is **memory-flat** (C, WASM — the handle is an address into linear memory) or **object-graph** (Objective-C, JS — the handle is a runtime object reference with no byte representation). That distinction gates the `abstract → typed_ptr T` cast — see `memory.md`.

---

## 2. Foreign Handles — `abstract`

```vertex
type SDL_Window   = abstract
type NSView       = abstract
type WebSocket    = abstract
type MessageEvent = abstract
```

An `abstract` type is a foreign resource Vertex holds by an opaque word: its interior belongs to the foreign environment and is invisible to the Vertex type system. It makes a statement about **knowledge**, not about layout — "structure exists, but Vertex declines to model it." It is **not** a `unique T` and must not be spelled as one, and it is not a raw pointer (`typed_ptr T` — see `memory.md`) — it supports no arithmetic, no dereference, and no stride, because it claims none.

**Copy does not exist for `abstract`.** A deep copy means "walk the pointee and duplicate it," and an abstract handle has no pointee Vertex can walk. An abstract handle can only be **accessed** or **moved**. This holds regardless of target: a WASM/C pointer, an Objective-C object reference, and a JS object reference are all `abstract` for the same reason — none of them expose a structural layout to Vertex.

**Zero value.** An abstract type has a zeroed representation, but it is legal **only** as an error-path value paired with a non-empty error string (the boundary tuple, §3; generics zero-value rule). Code must never hand a zeroed abstract handle down a success path. There is no comparable `nil` for abstract handles — absence is always the tuple.

Each abstract alias is a distinct **nominal** type. `SDL_Window` and `NSView` do not unify, cannot be assigned to one another, and never participate in `typed_ptr T`'s arithmetic or overloads. Bare `ref` is not a type in this language; writing `type X = ref` is a parse error with a fix-it pointing at `abstract`.

---

## 3. The Boundary Tuple (Fallibility & Null/Undefined)

Foreign functions do not throw exceptions into Vertex. Functions that can fail — a C-style function returning a potentially `NULL` pointer, or a JS API that can throw or return `undefined` — map to Vertex's standard Foundation error tuple (`-> (Value, string)`).

| Foreign Behavior | Vertex Interface Shape |
| --- | --- |
| Returns `T*` (Nullable) | `-> (T, string)` |
| Returns `status` and `T**` out-param | `-> (int32, T, string)` |
| JS call that may throw / return `undefined` | `-> (T, string)` |

* **On Success:** The handle receives a valid value, and the string is empty (`""`).
* **On Failure:** The handle is zeroed, and the runtime populates the string with a failure message (a caught JS exception's message, a fetched system error, or a literal like `"NULL pointer returned"`).

The wrapper layer must check this string before trusting the handle, matching standard Vertex semantics (Foundation §35.2). Not every foreign call needs this shape — a JS constructor that doesn't synchronously fail (like `WebSocket`, whose errors surface later as an event) is declared as an ordinary non-tuple return; see §4.4.

This convention is also how sentinel-null C idioms are absorbed without a `nil` value: a nullable `T*` becomes `(T, string)` **at the interface declaration**, so no null ever crosses into Vertex as a comparable pointer state.

---

## 4. Structural ABI Typing (Flat APIs vs. Object APIs)

Vertex does not use `objc`, `cpp`, `c`, or `js` keywords to select an object model. Instead, the compiler infers it from a single structural fact: **whether the interface declares any `init func`.**

### 4.1 The Flat Namespace — no `init func`

An interface that declares no `init func` is a flat bag of functions. It cannot be instantiated, and its functions are callable directly on the type.

```vertex
class SDL2_API : sdl2 {
    // No init func declared — SDL2 exposes no constructor.

    // Implicitly callable on the type itself: SDL2_API.SDL_Init(0)
    func SDL_Init(flags: uint32) -> (int32, string)
}
```

* **Compiler Guarantee:** With no declared `init func`, `let x = SDL2_API()` is a compile error (`error: 'SDL2_API' declares no initializer and cannot be instantiated`).
* **Fails closed:** Omitting every `init func` can never silently produce the wrong object model — the omission removes capability (instantiation) rather than granting it.

### 4.2 The Object API — one or more `init func` declarations

An interface representing a real, instantiable object declares its constructors with the `init` prefix modifier, one line per real constructor entry point in the foreign library.

```vertex
class NSWindow : AppKit {
    init func() -> NSWindow
    init func initWithContentRect(contentRect: Rect, styleMask: uint64, backing: uint64, defer: bool) -> NSWindow

    func center()
}
```

* `init` is a **prefix modifier** on `func`, not a function name. It marks the declaration as a constructor and requires the declared return type to be the enclosing class (`Self`).
* **Compiler Guarantee:** Declaring at least one `init func` marks the class as instantiable and tells the backend to treat it as a reference type over the target's real object model (Objective-C message passing + refcounting, C++ RAII, or a JS class instance), rather than a flat namespace.
* `defer` above is an ordinary parameter label, not a statement — see §5. It's written as-is because it's the real foreign label; there is no override syntax to reach for.

### 4.3 Naming Constructors — Zero-Arg vs. Named

Because a class may expose several real, independent constructor entry points (distinct Objective-C selectors, distinct C++ overloads, or distinct JS factory-style constructions), each `init func` beyond the trivial case carries its own name — there is no arity/type-based overload resolution among constructors, and none is needed.

* **Unnamed — `init func() -> Self`.** The one trivial "default" constructor path a class may declare **at most one of**. It's what bare `Type(...)` construction resolves to.
* **Named — `init func someName(...) -> Self`.** Any additional constructor. It's what `Type.someName(...)` resolves to. The name is exactly what the backend derives the foreign entry point from — there is no separate "real name" to reconcile it against.

```vertex
class NSAttributedString : AppKit {
    init func initWithString(string: string) -> NSAttributedString
    init func initWithStringAttributes(string: string, attributes: map[string]string) -> NSAttributedString
}
```

Two named constructors, two distinct Vertex names — `Type.initWithString(...)` and `Type.initWithStringAttributes(...)` at the call site. Each name is the whole contract: what's written is what's linked.

### 4.4 Constructors That Don't Need the Boundary Tuple

An `init func` is an ordinary declaration in every other respect, including whether it returns a boundary tuple (§3). A JS `WebSocket` constructor doesn't synchronously fail — errors surface later as an `error` event — so its `init func` returns bare `Self`, not `(Self, string)`:

```vertex
class WebSocket : websocket {
    init func(url: string) -> WebSocket
    init func withProtocols(url: string, protocols: string) -> WebSocket
}
```

Compare to a C API where failure is synchronous and must be checked immediately:

```vertex
class SDL2_API : sdl2 {
    // not a constructor — SDL2 is flat (§4.1) — shown for contrast
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
}
```

### 4.5 Illegal Forms

```vertex
class SDL2_API : sdl2 {
    private init func() -> SDL2_API   // error: visibility modifiers not allowed
                                       //        in an abstract interface

    func SDL_Init(flags: uint32) -> (int32, string) {
        return 0, ""                   // error: declarations in an abstract
    }                                  //        interface cannot have bodies
}

class Bad : AppKit {
    init func() -> Bad
    init func() -> Bad     // error: duplicate unnamed initializer —
                            //        only one `init func()` permitted per class

    init func broken(x: int32) -> int32
    //                            ^^^^^ error: `init func` must return the
    //                                  enclosing type (`Bad`), not `int32`
}
```

Abstract interfaces are declaration-only: no bodies, no visibility modifiers, no marker members beyond `init`, and no remapping clauses. Instantiability is expressed entirely by presence, count, and naming of `init func` declarations.

---

## 5. Non-Resource Pointer Shapes

| Foreign Shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*` (writable scalar out-param) | `mut T` |
| `T*` + length | `[]T` (read) / `mut []T` (write) |
| `T*` held and strided manually | `typed_ptr T` — raw pointer (see `memory.md`); last resort |
| JS property read / foreign static field | ordinary bodyless `func` returning the field's type |

Scalar out-params use `mut`: the call site is bare, the binding survives, and the foreign library writes through the pointer. `mut` here is an ABI *shape*, not an ownership claim, making it legal in the interface. A JS-backed accessor (e.g. reading `ws.readyState`) or a foreign static field (e.g. `System.out`) is declared the same as any other bodyless foreign function — the backend, not the grammar, decides whether that lowers to a call, a property load, or a static field read.

The shapes above cover the overwhelming majority of C signatures. `typed_ptr T` in a signature is the honest spelling for the residue — a pointer the caller must genuinely stride, poke, or retain past the call in ways `mut T` / `[]T` can't express. Prefer the safe shapes; every `typed_ptr T` in an interface is a promise that some wrapper somewhere is managing raw memory directly (see `memory.md`).

A parameter label is never looked up as an identifier — it's matched positionally against the foreign entry point, not resolved in any scope — so a Vertex keyword is a perfectly legal label. `defer: bool` in §4.2 is such a case: `defer` is reserved as a statement keyword elsewhere (foundation §28), but that has no bearing on its use as a label here, and there's nothing to disambiguate since interface declarations have no bodies for `defer` to appear in as a statement anyway.

---

## 6. The Abstract Interface Examples

```vertex
// A Flat C-API — no init func, not instantiable
class SDL2_API : sdl2 {
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
    func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)
    func SDL_PollEvent(event: mut uint32) -> int32
    func SDL_SetEventFilter(filter: func(int32) -> int32)
}

// An Objective-C Object API — multiple named constructors, instantiable
class NSWindow : AppKit {
    init func() -> NSWindow
    init func initWithContentRect(
        contentRect: Rect, styleMask: uint64, backing: uint64, defer: bool
    ) -> NSWindow

    func center()
}

// A JS Object API — one unnamed, one named constructor
type WebSocket    = abstract
type MessageEvent = abstract

class WebSocket : websocket {
    init func(url: string) -> WebSocket
    init func withProtocols(url: string, protocols: string) -> WebSocket

    func send(data: string)
    func close()
    func close(code: uint16, reason: string)
    func readyState() -> int32

    func addEventListener(kind: string, listener: func(MessageEvent))
    func removeEventListener(kind: string, listener: func(MessageEvent))
}

class MessageEvent_API : websocket {
    func data(event: MessageEvent) -> string
}
```

---

## 7. Wrapper Classes — the Safe Layer

RAII, no inheritance. Each wrapper owns its handle and frees, closes, or releases it in `deinit` (or via `shared`). This is the layer the reader is expected to write: the abstract interface alone is not safe to use directly.

### 7.1 A C Wrapper

```vertex
class Window {
    handle: SDL_Window
}

func (w: Window) init(title: string) {
    let handle, err = SDL2_API.SDL_CreateWindow(title, 0, 0, 800, 600, 2)
    if err != "" {
        panic("Failed to create window: " + err)
    }
    w.handle = handle
}

func (w: Window) deinit() {
    SDL2_API.SDL_DestroyWindow(w.handle)
}

func (w: Window) size() -> (int32, int32) {
    var width:  int32 = 0
    var height: int32 = 0
    SDL2_API.SDL_GetWindowSize(w.handle, width, height)
    return width, height
}
```

### 7.2 An Objective-C Wrapper, Using a Named Constructor

```vertex
class MainWindow {
    handle: NSWindow
}

func (w: MainWindow) init(rect: Rect) {
    // Type.name(...) resolves to the matching `init func name(...)` — §4.3
    w.handle = NSWindow.initWithContentRect(
        contentRect: rect, styleMask: 15, backing: 2, defer: false,
    )
}

func (w: MainWindow) deinit() {
}
```

Note `MainWindow.init` itself has a body (it is ordinary Vertex code), while every `init func` in an interface never does (each is a foreign symbol declaration). Bodies live in wrappers; declarations live in interfaces.

### 7.3 A JS Wrapper

```vertex
class Socket {
    handle: WebSocket
}

func (s: Socket) init(url: string) {
    // Unnamed init func() resolves to bare Type(...) construction — §4.3
    s.handle = WebSocket(url: url)

    s.handle.addEventListener("message", func(e: MessageEvent) {
        let text = MessageEvent_API.data(e)
        log.printf("recv: %s\n", text)
    })
}

func (s: Socket) initWithProtocols(url: string, protocols: string) {
    // Named init func resolves to Type.name(...) — §4.3
    s.handle = WebSocket.withProtocols(url: url, protocols: protocols)
}

func (s: Socket) deinit() {
    s.handle.close()
}

func (s: mut Socket) sendText(msg: string) {
    s.handle.send(msg)
}
```

---

## 8. Callbacks Across the Boundary

A boundary `func(...)` is a bare function pointer: one word, no environment. Only a **non-capturing** function converts across an abstract interface boundary — this applies uniformly to a C function pointer slot, an Objective-C block-shaped parameter, and a JS event-listener slot alike. A capturing closure is a fat `{code, env}` pair with nowhere to stash the `env` on the foreign side, and is rejected at compile time.

```vertex
func on_event(code: int32) -> int32 { return 0 }

// Legal: non-capturing function passed to the boundary
SDL2_API.SDL_SetEventFilter(on_event)
```

```vertex
var count = 0

SDL2_API.SDL_SetEventFilter(func(code: int32) -> int32 {
    count += 1        // error: capturing closure cannot cross the abstract boundary
    return 0
})
```

The same rule governs the JS listener slot from §6/§7.3:

```vertex
var received = 0

ws.addEventListener("message", func(e: MessageEvent) {
    received += 1      // error: capturing closure cannot cross the abstract boundary
})
```