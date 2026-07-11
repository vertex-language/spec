# Vertex Language Grammar

## Grammar — Abstract Interfaces (Grammar Reference)

---

## 0. Library Linking

```vertex
import "lib/sdl2"
import "darwin/framework/AppKit"
import "wasm/wasi_snapshot_preview1"
import "js/websocket"
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

```vertex
// Flat namespace — no init func declared
class SDL2_API : sdl2 {
    func SDL_Init(flags: uint32) -> (int32, string)
}
```

```vertex
// Object API — unnamed constructor
class NSView : AppKit {
    init func() -> NSView
}
```

```vertex
// Object API — unnamed + named constructors
// `defer` is an ordinary parameter label, matched positionally,
// not looked up as an identifier — keyword spellings are fine (§5)
class NSWindow : AppKit {
    init func() -> NSWindow
    init func initWithContentRect(
        contentRect: Rect, styleMask: uint64, backing: uint64, defer: bool
    ) -> NSWindow

    func center()
}
```

```vertex
// Two named constructors — each name is used verbatim, no remapping
class NSAttributedString : AppKit {
    init func initWithString(string: string) -> NSAttributedString
    init func initWithStringAttributes(string: string, attributes: map[string]string) -> NSAttributedString
}
```

```vertex
// JS Object API — unnamed + named constructors, no boundary tuple needed
class WebSocket : websocket {
    init func(url: string) -> WebSocket
    init func withProtocols(url: string, protocols: string) -> WebSocket
}
```

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
    init func() -> Bad     // error: duplicate unnamed initializer

    init func broken(x: int32) -> int32   // error: must return enclosing type
}
```

---

## 4. Non-Resource Pointer Shapes

| Foreign Shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*` (writable scalar out-param) | `mut T` |
| `T*` + length | `[]T` (read) / `mut []T` (write) |
| `T*` held and strided manually | `typed_ptr T` — raw pointer (see memory.md) |
| JS property read / foreign static field | ordinary bodyless `func` returning the field's type |

A parameter label is matched positionally, never looked up as an identifier — Vertex keywords are legal labels (e.g. `defer: bool` above).

---

## 5. Abstract Interface Examples

```vertex
// A Flat C-API — no init func, not instantiable
class SDL2_API : sdl2 {
    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> (SDL_Window, string)
    func SDL_DestroyWindow(window: SDL_Window)
    func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)
    func SDL_PollEvent(event: mut uint32) -> int32
    func SDL_SetEventFilter(filter: func(int32) -> int32)
}

// An Objective-C Object API — multiple named constructors
class NSWindow : AppKit {
    init func() -> NSWindow
    init func initWithContentRect(
        contentRect: Rect, styleMask: uint64, backing: uint64, defer: bool
    ) -> NSWindow

    func center()
}

// A JS Object API — unnamed + named constructors
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

## 6. Wrapper Classes — the Safe Layer

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

```vertex
// Wrapper using a named constructor — Type.name(...)
class MainWindow {
    handle: NSWindow
}

func (w: MainWindow) init(rect: Rect) {
    w.handle = NSWindow.initWithContentRect(
        contentRect: rect, styleMask: 15, backing: 2, defer: false,
    )
}
```

```vertex
// JS wrapper — unnamed constructor via bare Type(...)
class Socket {
    handle: WebSocket
}

func (s: Socket) init(url: string) {
    s.handle = WebSocket(url: url)

    s.handle.addEventListener("message", func(e: MessageEvent) {
        let text = MessageEvent_API.data(e)
        log.printf("recv: %s\n", text)
    })
}

func (s: Socket) initWithProtocols(url: string, protocols: string) {
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

## 7. Callbacks Across the Boundary

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

```vertex
var received = 0

ws.addEventListener("message", func(e: MessageEvent) {
    received += 1      // error: capturing closure cannot cross the abstract boundary
})
```