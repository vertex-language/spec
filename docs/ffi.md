# Vertex Language Grammar

## Specification 2.3 — FFI & Native Interop

---

## 1. Library Linking

```vertex
import "lib/sdl2"
import "dynamic/lib/cuda"
```

---

## 2. Opaque Handles — `unique`

```vertex
type SDL_Window = unique
type SDL_Renderer = unique
type SDL_Texture = unique
```

An opaque handle is absorbed into the ownership system as a
unique pointer — one word, never null, same as a class handle.
It obeys the full shared / `mut` / `own` ladder like any other value.

---

## 3. Non-Resource Pointer Shapes

| C shape | Vertex form |
|---|---|
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| `T*` (writable scalar out-param) | `mut T` |
| `T**` | `-> T?` or `-> (int32, T?)` |
| `T*` + length | `[T]` (read) / `mut [T]` (write) |

```vertex
func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)

var width = 0
var height = 0
SDL2_API.SDL_GetWindowSize(window.handle, mut width, mut height)
```

---

## 4. The `T**` Case

```vertex
func SDL_CreateMessage(text: string) -> SDL_Message?
```

```vertex
func SDL_CreateMessage(text: string) -> (int32, SDL_Message?)
```

---

## 5. The Flat ABI Namespace

```vertex
class SDL2_API : sdl2 {
    func SDL_Init(flags: uint32) -> int32
    func SDL_Quit()

    func SDL_CreateWindow(title: string, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> SDL_Window
    func SDL_DestroyWindow(window: own SDL_Window)
    func SDL_SetWindowTitle(window: SDL_Window, title: string)
    func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)

    func SDL_CreateRenderer(window: SDL_Window, index: int32, flags: uint32) -> SDL_Renderer
    func SDL_DestroyRenderer(renderer: own SDL_Renderer)
    func SDL_RenderClear(renderer: SDL_Renderer) -> int32
    func SDL_RenderPresent(renderer: SDL_Renderer)
    func SDL_RenderCopy(renderer: SDL_Renderer, texture: SDL_Texture, src: [int32], dst: [int32]) -> int32

    func SDL_CreateTextureFromSurface(renderer: SDL_Renderer, surface: [uint8]) -> SDL_Texture
    func SDL_DestroyTexture(texture: own SDL_Texture)

    func SDL_CreateMessage(text: string) -> SDL_Message?

    func SDL_PollEvent(event: mut uint8) -> int32

    func SDL_SetEventFilter(filter: func(int32) -> int32)
}
```

---

## 6. Parameter Passing Forms

| C function does... | Vertex form |
|---|---|
| reads/uses the handle | `x: T` |
| mutates the handle's pointee in place | `x: mut T` |
| frees/destroys/transfers away the handle | `x: own T` |
| hands back a brand-new owned object | not a parameter — see §4 |
| reads a raw C array | `x: [T]` |
| writes into a raw C array | `x: mut [T]` |
| takes a callback | `x: func(...) -> R` |

The destroy row is ordinary Move semantics (2.5 §3): the call site
is bare, and Move Invalidation makes any later use of the handle a
compile error — double-free and use-after-destroy are unrepresentable.

```vertex
SDL2_API.SDL_DestroyWindow(w.handle)
SDL2_API.SDL_RenderClear(...)          // any later use of w.handle:
                                       // error: use of moved value
```

---

## 7. Wrapper Classes

```vertex
class Window {
    handle: SDL_Window
    engine: SDLEngine
}

func (w: Window) init(engine: SDLEngine, title: string) {
    w.engine = engine
    w.handle = SDL2_API.SDL_CreateWindow(title, 0, 0, 800, 600, 2)
}

func (w: Window) deinit() {
    SDL2_API.SDL_DestroyWindow(w.handle)
}

class Renderer {
    handle: SDL_Renderer
}

func (r: Renderer) init(window: Window) {
    r.handle = SDL2_API.SDL_CreateRenderer(window.handle, -1, 0)
}

func (r: Renderer) deinit() {
    SDL2_API.SDL_DestroyRenderer(r.handle)
}

func (r: Renderer) clear() {
    SDL2_API.SDL_RenderClear(r.handle)
}

func (r: Renderer) present() {
    SDL2_API.SDL_RenderPresent(r.handle)
}
```

---

## 8. Full Example

```vertex
let engine = shared(SDLEngine())

let window = Window(engine: engine, title: "My App")
let renderer = Renderer(window: window)

renderer.clear()
renderer.present()
```

---

## 9. Callbacks into C

```vertex
func on_event(code: int32) -> int32 { return 0 }
SDL2_API.SDL_SetEventFilter(on_event)
```

```vertex
var count = 0
SDL2_API.SDL_SetEventFilter(func(code: int32) -> int32 {
    count += 1
    return 0
})
```