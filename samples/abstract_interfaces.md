## Abstract Interfaces

---

## 0. Build Tags and ABI Linkage

A declare block describes the *call shape* of code Vertex does not compile. What
that shape lowers to — a C symbol, a C++ vtable slot, an Objective-C message send,
a JS property access — is not written in the block. It comes from the file's build
tag.

```vertex
package sdl2
build linux       // C ABI

declare module "sdl2" { … }
```

```vertex
package dom
build js          // JS object graph

declare module "websocket" { … }
```

A `BuildClause` is syntactically optional (grammar, *Source file*), so a file with
no build tag parses. **A file containing a `declare framework` or `declare module`
block requires one anyway** — this is a static rule, not a grammatical one, and the
diagnostic names the block rather than the missing clause. There is no default
linkage: without a tag there is nothing for the block to resolve against.

The string after `framework` or `module` is the library or framework to link, not a
package name. The qualifier under which its symbols are reached comes from the
enclosing file's `package` clause (foundation §30), which is why `package dom` above
can hold a block naming `"websocket"`, and why a client writes `import "dom"` and
then `dom.WebSocket`.

| `build` | Linkage | Handles are |
| --- | --- | --- |
| `linux`, `windows` | C / C++ / COM | addresses into linear memory |
| `darwin` | C / C++ for `declare module`; Objective-C for `declare framework` | memory-flat / object references |
| `wasm` | C ABI over linear memory | addresses into linear memory |
| `js` | JS object graph | runtime object references |

Which side of that last column a handle falls on is what decides whether it can be
cast to a `typed_ptr` (memory §8).

---

## 1. Foreign Handles — `abstract`

A foreign object Vertex never looks inside gets an `abstract` type. It is a named,
opaque handle: no fields, no layout, no arithmetic, no dereference. The only things
you can do with one are hold it, pass it back across the boundary, and — where the
linkage permits — reinterpret it (memory §8).

```vertex
type SDL_Window   = abstract
type NSView       = abstract
type WebSocket    = abstract
type MessageEvent = abstract
```

`abstract` is legal only as the target of a type alias (grammar, *Abstract types*).
Every alias is nominally distinct: two `abstract` types are unrelated even when the
foreign library treats one as a subtype of the other, and there is no conversion
between them.

```vertex
type SDL_Window = ref          // error: unknown type `ref`
```

`ref` is an ordinary identifier that names nothing — the alias target position takes
a `Type` or the keyword `abstract`, and `ref` is neither a declared type nor a
keyword. The diagnostic can suggest `abstract`, but the rule it broke is name
resolution, not a reserved word.

---

## 2. The Boundary Tuple

Foreign code reports failure in whatever way its own conventions favour: a null
return, a status code with an out-param, a thrown exception, an `undefined`. Vertex
has one shape for all of it — the boundary tuple of foundation §35, with a `string`
that is empty on success.

| Foreign behavior | Vertex interface shape |
| --- | --- |
| Returns `T*`, may be null | `-> (T, string)` |
| Returns a status code and fills a `T**` out-param | `-> (int32, T, string)` |
| JS call that may throw or return `undefined` | `-> (T, string)` |
| Cannot fail | `-> T`, or no `->` at all |

On the error path the handle slot holds the `abstract` type's zeroed
representation. That value is legal **only** there, paired with a non-empty string.
It is never compared against `nil` — `nil` belongs to `typed_ptr T` and to nothing
else (memory §13). Check the string; the handle is not a null you can test.

```vertex
let handle, err = sdl2.SDL_CreateWindow("demo", 0, 0, 800, 600, 2)
if err != "" {
    // `handle` is zeroed and unusable — do not inspect it
}
```

**Initializers are the exception, and it is a grammatical one.** A
`ForeignInitDecl`'s result is written `"->" TypeName` (grammar, *Declare blocks*) —
a single named type, not a `Type`, so a tuple cannot be written there at all. A
foreign constructor therefore has no error channel; see §7.

---

## 3. Structural ABI Typing

There are two block forms. `declare framework` names a bundled,
message-passing library; `declare module` names a flat one. Both take
`ForeignFuncDecl`, `ForeignClassDecl`, and nothing else that means anything (§3.5,
§3.6).

### 3.1 Bodyless Declarations

Every member of a declare block is a signature and a line terminator. That is the
entire content model: the block says what a call looks like, and the foreign
library supplies what it does.

### 3.2 `declare framework` — Bundled, Message-Passing Libraries

```vertex
package appkit
build darwin

type Rect = abstract

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

On `darwin` this is always Objective-C message passing. There is no variant tag to
write and none is accepted (§3.4).

Two things in that block are worth naming:

* **`init func` is a prefix on `func`, not a method named `init`.** The unnamed form
  is what bare `NSWindow()` construction resolves to; the named form
  (`initWithContentRect`) is reached as a member of the type,
  `NSWindow.initWithContentRect(…)`.
* **`defer` is a keyword.** It appears above as a parameter name because the
  Objective-C selector uses it, and a `ParameterDecl`'s name is an `identifier` —
  which `defer` is not. This is a real conflict the corpus does not resolve; see §7.

### 3.3 `declare module` — Flat Namespace

Loose functions, no enclosing type:

```vertex
package sdl2
build linux

type SDL_Window = abstract

declare module "sdl2" {
    func SDL_CreateWindow(title: string, x: int32, y: int32,
                          w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
    func SDL_SetEventFilter(filter: func(int32) -> int32)
}
```

A `declare module` may also nest a class, which is how an object API is described:

```vertex
package dom
build js

type WebSocket = abstract

declare module "websocket" {
    class WebSocket {
        init func(url: string) -> WebSocket
        init func withProtocols(url: string, protocols: string) -> WebSocket

        func send(data: string)
        func close()
    }
}
```

**Default call convention when a `declare module` block nests a class:**

| `build` | Default |
| --- | --- |
| `darwin` | C++, Itanium ABI, exceptions on |
| `linux` | C++, Itanium ABI, exceptions on |
| `windows` | Raw C++ vtable call |
| `js` | Ordinary JS object/class call shape |
| `wasm` | C ABI — a nested class has no distinct lowering |

### 3.4 Variant Tags — `declare module[...]`

A variant tag narrows the default in §3.3's table. It never grants a capability the
default lacks — it selects among conventions the linkage already supports.

```vertex
// Windows COM instead of the default raw-vtable C++ call
declare module["windows", "com"] "some.dll" {
    class ISomeInterface {
        func Release() -> uint32
    }
}
```

```vertex
// Pin a specific C++ variant instead of the darwin/linux default
declare module["cxx", "no-exceptions"] "libfoo" {
    class Foo {
        init func() -> Foo
    }
}
```

* Bracket contents are a closed set of string tags, checked against the file's
  `build`; an illegal combination is a compile error.
* Omitting the bracket means "use §3.3's default table."

`declare framework` never takes a tag. The grammar hoists `VariantTag` out of the
`module` branch specifically so the tagged framework form parses and can be
diagnosed by name:

```vertex
declare framework["windows", "com"] "SomeLib" {   // error: `declare framework`
    class Foo { }                                 //        never takes a variant tag
}
```

### 3.5 Rejected Members

Each of the following parses, so the diagnostic can name the construct rather than
reporting a syntax error.

```vertex
declare module "sdl2" {
    func SDL_Init() -> int32 {
        return 0            // error: a declaration in an abstract interface
    }                       //        cannot have a body
}
```

```vertex
declare module "sdl2" {
    func SDL_Poll() async -> int32
                            // error: a foreign declaration cannot carry a
                            //        function marker
}
```

```vertex
declare module "outer" {
    declare module "inner" {  // error: declare blocks do not nest
    }
}
```

The marker rejection is the substantive one: `async`, `gpu`, `npu`, and `test` are
properties of a body Vertex compiles, and a declare block has no body. A foreign
call that blocks is wrapped by an `async` Vertex function around the readiness
primitive (async §8.3), not marked at the boundary.

### 3.6 No Layout Crosses the Boundary

```vertex
declare module "libfoo" {
    class Foo {
        payload: string     // error: fields describe layout — an abstract
    }                       //        interface describes call shape only
}
```

A foreign field read is an ordinary bodyless `func` returning the field's type
(§4). This keeps the block honest about what it is: a list of calls, none of which
commits Vertex to a byte offset.

---

## 4. Non-Resource Pointer Shapes

Not every foreign pointer is a handle. A `T*` that means "a buffer," "an out-param,"
or "a string" gets an ordinary Vertex type, not an `abstract` one.

| Foreign shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*`, writable scalar out-param | `mut T` |
| `T*` plus a length | `[]T` (read) / `mut []T` (write) |
| `T*` held and strided manually | `typed_ptr T` — raw pointer (memory.md) |
| `T**` out-param not absorbed by the boundary tuple | `typed_ptr (typed_ptr T)`, via `addr` (memory §2.1) |
| JS property read / foreign static field | ordinary bodyless `func` returning the field's type |

A Vertex `string` is UTF-8 bytes with a length and no NUL terminator (grammar,
*String literals*); the terminator is added and stripped at the boundary, and the
foreign side never sees the length header.

---

## 5. Wrapper Classes — the Safe Layer

Client code should not hold an `abstract` handle directly. The idiom is a small
Vertex class that owns the handle, converts the boundary tuple into whatever the
caller should see, and releases the resource in `deinit`.

```vertex
package windowing
build linux

import "sdl2"

class Window {
    handle: sdl2.SDL_Window
}

func (w: Window) init(title: string) {
    let handle, err = sdl2.SDL_CreateWindow(title, 0, 0, 800, 600, 2)
    if err != "" {
        panic("failed to create window: " + err)
    }
    w.handle = handle
}

func (w: Window) deinit() {
    sdl2.SDL_DestroyWindow(w.handle)
}
```

An `init` receiver is implicitly exclusive and is written bare (foundation §25),
which is why `init` assigns `w.handle` without a `mut` qualifier.

`panic` above is a choice, not a requirement: an initializer has no error channel
(foundation §27 constructs a class by calling one, and there is no failing form). A
wrapper that must report failure exposes a factory function returning the boundary
tuple instead:

```vertex
func openWindow(title: string) -> (Window, string) {
    let handle, err = sdl2.SDL_CreateWindow(title, 0, 0, 800, 600, 2)
    if err != "" {
        var zero: Window
        return zero, err
    }
    return Window(handle: handle), ""
}
```

The JS side looks the same, with the two initializer forms of §3.3 reached the two
ways §3.2 describes:

```vertex
package net
build js

import "dom"

class Socket {
    handle: dom.WebSocket
}

func (s: Socket) init(url: string) {
    s.handle = dom.WebSocket(url: url)                  // unnamed init
}

func (s: Socket) initWithProtocols(url: string, protocols: string) {
    s.handle = dom.WebSocket.withProtocols(url: url,    // named init
                                           protocols: protocols)
}

func (s: Socket) deinit() {
    s.handle.close()
}
```

And a framework handle:

```vertex
package windowing
build darwin

import "appkit"

class Window {
    handle: appkit.NSWindow
}

func (w: Window) init() {
    w.handle = appkit.NSWindow()
}
```

---

## 6. Callbacks Across the Boundary

A function passed to foreign code must be a plain code pointer. Vertex closures
capture by value at creation (foundation §32), so a capturing closure carries an
environment the foreign side has no way to receive.

```vertex
func on_event(code: int32) -> int32 {
    return 0
}

sdl2.SDL_SetEventFilter(on_event)          // legal — a declared function
```

An anonymous function is equally fine as long as it captures nothing:

```vertex
sdl2.SDL_SetEventFilter(func(code: int32) -> int32 {
    return 0
})
```

Reading an enclosing binding is what fails, and it fails at the boundary rather
than at the closure:

```vertex
let threshold = 5

sdl2.SDL_SetEventFilter(func(code: int32) -> int32 {
    if code > threshold {                  // error: a capturing closure cannot
        return 1                           //        cross the abstract boundary
    }
    return 0
})
```

The capture above is legal Vertex — `threshold` is read, not written, so
foundation §32's rule about writing through a captured copy never comes up. The
diagnostic belongs to this document alone. To thread state into a callback, use the
userdata pointer the foreign API provides, or a package-level binding.