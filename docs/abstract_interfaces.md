# Vertex Language Grammar

## Grammar — Abstract Interfaces (Grammar Reference)

---

## 0. Build Tags and ABI Linkage

A `declare framework` or `declare module` block requires a valid `build` tag in the file to determine base linkage.

```vertex
package sdl2
build linux       // Resolves to C-ABI on Linux

package dom
build js          // Resolves to JS object graph

```

---

## 1. Foreign Handles — `abstract`

```vertex
type SDL_Window   = abstract
type NSView       = abstract
type WebSocket    = abstract
type MessageEvent = abstract

```

```vertex
type SDL_Window = ref          // error: bare `ref` is not a type —
                                //        did you mean `abstract`?

```

---

## 2. The Boundary Tuple

| Foreign Behavior | Vertex Interface Shape |
| --- | --- |
| Returns `T*` (Nullable) | `-> (T, string)` |
| Returns `status` and `T**` out-param | `-> (int32, T, string)` |
| JS call that may throw / return `undefined` | `-> (T, string)` |

---

## 3. Structural ABI Typing

### 3.1 `declare framework` — Bundled, Message-Passing Libraries

```vertex
// Always Objective-C message passing on darwin. No variant tag — see §3.4.
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

### 3.2 `declare module` — Flat Namespace

```vertex
// Flat namespace — loose functions inside the module block
declare module "sdl2" {
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
}

```

### 3.3 `declare module` — Object API

```vertex
// JS Object API — no boundary tuple needed for delayed constructors
declare module "websocket" {
    class WebSocket {
        init func(url: string) -> WebSocket
        init func withProtocols(url: string, protocols: string) -> WebSocket
        
        func send(data: string)
        func close()
    }
}

```

**Default convention when a `declare module` block nests a `class`:**

| `build` | Default |
| --- | --- |
| `darwin` | C++, Itanium ABI, exceptions on |
| `linux` | C++, Itanium ABI, exceptions on |
| `windows` | Raw C++ vtable call |
| `js` | Ordinary JS object/class call shape |

### 3.4 Variant Tags — `declare module[...]`

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

```vertex
declare framework["windows", "com"] "SomeLib" {  // error: `declare framework`
    class Foo { }                                //        never takes a variant tag
}

```

* Bracket contents are a closed set of string tags, checked against `build`; illegal combinations are compile errors.
* Omitting the bracket means "use §3.3's default table." The bracket only narrows an existing default — it never grants a capability the default lacks.

### 3.5 Bodies Are Illegal in Either Block

```vertex
declare module "sdl2" {
    func SDL_Init() -> int32 {
        return 0                   // error: declarations in an abstract
    }                              //        interface cannot have bodies
}

```

### 3.6 No Layout Crosses the Boundary

```vertex
declare module "libfoo" {
    class Foo {
        payload: string           // error: fields describe layout — abstract
    }                              //        interfaces describe call shape only
}

```

---

## 4. Non-Resource Pointer Shapes

| Foreign Shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*` (writable scalar out-param) | `mut T` |
| `T*` + length | `[]T` (read) / `mut []T` (write) |
| `T*` held and strided manually | `typed_ptr T` — raw pointer |
| JS property read / foreign static field | ordinary bodyless `func` returning the field's type |

---

## 5. Wrapper Classes — the Safe Layer

```vertex
package windowing
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

```vertex
package net
import "dom"

class Socket {
    handle: dom.WebSocket
}

func (s: Socket) init(url: string) {
    s.handle = dom.WebSocket(url: url)
}

func (s: Socket) initWithProtocols(url: string, protocols: string) {
    s.handle = dom.WebSocket.withProtocols(url: url, protocols: protocols)
}

func (s: Socket) deinit() {
    s.handle.close()
}

```

```vertex
package windowing
import "appkit"   // holds a `declare framework "AppKit"` block

class Window {
    handle: appkit.NSWindow
}

func (w: Window) init() {
    w.handle = appkit.NSWindow()
}

```

---

## 6. Callbacks Across the Boundary

```vertex
func on_event(code: int32) -> int32 { return 0 }

// Legal: non-capturing function passed to the boundary
sdl2.SDL_SetEventFilter(on_event)

```

```vertex
var count = 0

sdl2.SDL_SetEventFilter(func(code: int32) -> int32 {
    count += 1        // error: capturing closure cannot cross the abstract boundary
    return 0
})

```