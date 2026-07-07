# Vertex Language Reference: FFI & Native Interop

## Specification 2.2 — Semantics & Rationale

Companion to `ffi.md`, same section numbers. Includes the same code as
`ffi.md` plus the reasoning behind each form.

---

## 1. Library Linking Strategies

```vertex
import "lib/sdl2"              // link-time resolution: .a/.so/.dll/.dylib
import "dynamic/lib/cuda"      // runtime dlopen/dlsym, generated automatically
```

Two strategies exist because C libraries are consumed two different ways
in practice: resolved at build time, or loaded at runtime via
`dlopen`/`dlsym`. The `dynamic/` import path generates that boilerplate
automatically — writing it by hand is exactly the kind of mechanical,
error-prone plumbing a compiler should own, the same principle that later
governs callback trampolines in §9.

---

## 2. Opaque Handles — `unique`

```vertex
type SDL_Window = unique
type SDL_Renderer = unique
type SDL_Texture = unique
```

There is no separate "unsafe pointer" tier in Vertex. An external C
resource is just a **linear value** — move-only, like any other resource
under the ownership model in `ownership.md`. There is nothing to unlock,
so there is no inheritance ceremony, and `*` never appears in user-facing
signatures.

`unique` is not a generic wrapper (there's no separate `SDL_Window` type
it could parameterize — the declaration line *is* the definition). It's a
nominal kind marker: no fields, no copy — only move via postfix `&`,
exactly like `Widget&` in `ownership.md` §3. The compiler tracks it as a
linear value and enforces single ownership, use-after-move, and
exactly-once release the same way it already does for any other resource.
There's no `*` because the pointer-ness is a codegen detail, never
something the programmer names.

---

## 3. Non-Resource Pointer Shapes

| C shape | Vertex form | Why |
|---|---|---|
| `const char*` | `cstr` | read-only, null-terminated, ephemeral view — produced by `.c_str()`, valid only for the call |
| `T*` (writable scalar out-param, e.g. `int*`) | `mut T` | a borrowed writable slot — identical to `increment(n: mut int32)` in `ownership.md` §2.3 |
| `T**` (hand back a brand-new owned object) | plain return: `-> T?`, or `-> (int32, T?)` if an error code also needs returning | see §4 — never a parameter shape |
| `T*` + length (raw array/view, e.g. `uint8*`) | `[T]` (read) / `mut [T]` (write) | an ordinary borrowed array, same as `Widget` — `ownership.md` §1/§2 apply unchanged, no dedicated buffer type needed |

```vertex
func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)

var width = 0
var height = 0
SDL2_API.SDL_GetWindowSize(window.handle, mut width, mut height)
```

Not every C pointer is an owned resource — some are transient views or
plain borrowed out-params. Each row maps onto a construct the grammar
already has, so `*` never appears in user code and no new type
constructor is invented. A dedicated buffer type for the `T*` + length
case would just be `[T]` with extra ceremony, so none is introduced.

---

## 4. The `T**` Case — Collapses to a Return Value, Not a Parameter

A C API like:

```c
SDL_Result SDL_CreateMessage(const char* text, SDL_Message** out_msg);
```

looks like an out-param, but it's really a C-ism for "return a second
thing because C only has one return slot." Idiomatic C++ never keeps the
`T**` shape either — it collapses to a plain returned `unique_ptr` (or
`optional<unique_ptr<T>>` if creation is fallible), with the raw pointer
living only inside the one-line binding shim. Vertex already has real
optionals and real multiple returns (`foundation.md` §25, §31.6), so the
binding should do the same collapse and never expose `T**` as a parameter
shape at all:

```vertex
func SDL_CreateMessage(text: cstr) -> SDL_Message?
```

If the C signature's error code is worth preserving instead of collapsing
into `nil`, use a tuple return instead:

```vertex
func SDL_CreateMessage(text: cstr) -> (int32, SDL_Message?)
```

Which of these two a given function gets is a per-function judgment call
made when writing the binding — not a grammar gap. The grammar doesn't
decide this for you; it just makes both shapes equally easy to express.

---

## 5. The Flat ABI Namespace — a Binding, Not a Class

```vertex
class SDL2_API : sdl2 {
    func SDL_Init(flags: uint32) -> int32
    func SDL_Quit()

    func SDL_CreateWindow(title: cstr, x: int32, y: int32, w: int32, h: int32, flags: uint32) -> SDL_Window
    func SDL_DestroyWindow(window: SDL_Window&)
    func SDL_SetWindowTitle(window: SDL_Window, title: cstr)
    func SDL_GetWindowSize(window: SDL_Window, w: mut int32, h: mut int32)

    func SDL_CreateRenderer(window: SDL_Window, index: int32, flags: uint32) -> SDL_Renderer
    func SDL_DestroyRenderer(renderer: SDL_Renderer&)
    func SDL_RenderClear(renderer: SDL_Renderer) -> int32
    func SDL_RenderPresent(renderer: SDL_Renderer)
    func SDL_RenderCopy(renderer: SDL_Renderer, texture: SDL_Texture, src: [int32], dst: [int32]) -> int32

    func SDL_CreateTextureFromSurface(renderer: SDL_Renderer, surface: [uint8]) -> SDL_Texture
    func SDL_DestroyTexture(texture: SDL_Texture&)

    func SDL_CreateMessage(text: cstr) -> SDL_Message?

    func SDL_PollEvent(event: mut uint8) -> int32

    func SDL_SetEventFilter(filter: func(int32) -> int32)
}
```

> **This is not inheritance.** `class X : lib_name { ... }` is
> special-cased syntax reserved for FFI binding declarations only — it
> declares a stateless symbol table resolved by the linker, never a real
> base/derived class relationship. It is the *only* place `:` after a
> class name means something other than normal inheritance. Ordinary code
> (§7) never inherits from an FFI binding — the lookalike syntax is
> deliberately confined to this one context so it can't be mistaken for,
> or abused as, real inheritance elsewhere.

### Choosing bare / `mut` / `&` per function

Ask: **would the C++ equivalent need `unique_ptr::release()`-style
ownership transfer to call this safely?**

| C function does... | Vertex form | Why |
|---|---|---|
| reads/uses the handle, doesn't invalidate it | `x: T` (bare) | matches `func f1(x: T)` in `ownership.md` §4 — read, reusable after |
| mutates the handle's pointee in place, doesn't invalidate it | `x: mut T` | matches `func f2(x: mut T)` |
| frees/destroys/transfers away the handle — its terminal use | `x: T&` | matches `func f3(x: T&)` — the `unique_ptr` deleter test |
| hands back a brand-new owned object | not a parameter at all — see §4 | collapses to a return value, same as idiomatic C++ |
| reads a raw C array | `x: [T]` | ordinary borrow, no dedicated buffer type |
| writes into a raw C array | `x: mut [T]` | ordinary mutable borrow |
| takes a callback | `x: func(...) -> R` | see §9 — capture handling is a codegen concern, not new grammar |

Worked against the table above:
- `SDL_DestroyWindow` / `SDL_DestroyRenderer` / `SDL_DestroyTexture` → `&`. Each is the handle's last legal use, same as a `unique_ptr` deleter.
- `SDL_SetWindowTitle`, `SDL_RenderClear`, `SDL_RenderPresent`, `SDL_RenderCopy` → bare. The window/renderer/texture stays valid and gets reused every frame — nothing terminal happens.
- `SDL_CreateRenderer` takes `window: SDL_Window` bare, not `&`, because SDL keeps the window alive independently of the renderer — creating a renderer doesn't consume the window.
- `SDL_GetWindowSize` → `mut int32` scalar out-params, matching Rust's `&mut i32` idiom for the same shape.
- `SDL_CreateMessage` → returns `SDL_Message?` directly rather than taking a `T**`-shaped parameter, per §4.
- `SDL_CreateTextureFromSurface` → `surface: [uint8]`, an ordinary borrowed array, same rule as passing a `Widget` by value in `ownership.md` §1.
- `SDL_SetEventFilter` → `filter: func(int32) -> int32`, an ordinary first-class function value, per §9.

---

## 6. What's Actually Enforced

- `unique` values: move-only, exactly-once deinit, use-after-move is a compile error — identical machinery to `ownership.md` §3, §7, §8. No new rules needed; FFI handles get ownership safety for free by riding on the existing linear-value machinery rather than a bolted-on pointer checker.
- There's no way to "downgrade" a `unique` into a raw pointer-shaped field on a normal class, because there's no raw pointer type exposed at all — the fake-pointer-as-array pattern (common in other languages' FFI layers as an escape hatch) simply isn't needed anymore, so there's nothing to reject.

---

## 7. Wrapper Classes — Plain RAII, No Inheritance

Because `SDL_Window` behaves like any other linear value, a wrapper needs
**no special permission** to hold one. Classes declare fields only in the
body; methods attach externally via receiver syntax — same shape as
`Animal` in `foundation.md` §29.

```vertex
class Window {
    handle: SDL_Window
    engine: SDLEngine
}

func (w: Window) init(engine: SDLEngine, title: string) {
    w.engine = engine
    w.handle = SDL2_API.SDL_CreateWindow(title.c_str(), 0, 0, 800, 600, 2)
}

func (w: Window) deinit() {
    SDL2_API.SDL_DestroyWindow(w.handle&)
}

class Renderer {
    handle: SDL_Renderer
}

func (r: Renderer) init(window: Window) {
    r.handle = SDL2_API.SDL_CreateRenderer(window.handle, -1, 0)
}

func (r: Renderer) deinit() {
    SDL2_API.SDL_DestroyRenderer(r.handle&)
}

func (r: Renderer) clear() {
    SDL2_API.SDL_RenderClear(r.handle)
}

func (r: Renderer) present() {
    SDL2_API.SDL_RenderPresent(r.handle)
}
```

`class Window : SDL2_API` (wrapper-inherits-binding) is gone. There's
nothing to unlock, so there's nothing to inherit for — every call site
goes through the binding class explicitly
(`SDL2_API.SDL_CreateWindow(...)`), same as calling any other namespaced
function. If ergonomic `w.SDL_CreateWindow(...)` sugar is still wanted
later, it'd need to come back as an explicit, separate mixin feature —
not bundled back into the pointer-safety story, since that story no
longer exists. Keeping these concerns separate means adding sugar later
can't accidentally reopen the inheritance-based unsafety the design
removed.

---

## 8. Full Example

```vertex
let engine = shared(SDLEngine())

let window = Window(engine: engine, title: "My App")
let renderer = Renderer(window: window)

renderer.clear()
renderer.present()

// scope ends -> Renderer.deinit() -> Window.deinit() -> SDLEngine.deinit()
```

This teardown order falls out of ordinary RAII with no special FFI-specific
rule: `Renderer.deinit()` runs before `Window.deinit()` before
`SDLEngine.deinit()` purely because of normal nested-scope destruction
order — the same order any class hierarchy would unwind in. Nothing about
holding a `unique` handle changes that order or requires annotating it.

---

## 9. Callbacks into C

A C callback pointer (`void (*)(int)`) is just a code address — no room
for captured environment. A Vertex closure that captures something is a
"fat" value (function pointer + captured state), so the two cases need
different treatment. Rust hits the identical wall: a non-capturing
closure coerces to a raw `fn` pointer for free; a capturing one cannot
cross an `extern "C"` boundary directly.

**Non-capturing** — free coercion, zero overhead, no new syntax. The
existing first-class function type from `foundation.md` §33/34 is all
that's needed:

```vertex
func on_event(code: int32) -> int32 { return 0 }
SDL2_API.SDL_SetEventFilter(on_event)
```

**Capturing** — real C callback APIs (SDL, CUDA, libcurl) solve this with
a `void* userdata` parameter alongside the function pointer: captured
state is boxed, its address passed as `userdata`, and a trampoline on the
C side unboxes it and calls back into the real Vertex closure. This
boxing + trampoline generation is a **compiler/codegen responsibility** —
the same treatment `dlopen`/`dlsym` boilerplate already gets in §1 — never
something the Vertex programmer writes by hand:

```vertex
var count = 0
SDL2_API.SDL_SetEventFilter(func(code: int32) -> int32 {
    count += 1     // captured by value, per foundation.md §34
    return 0
})
```

Pushing this to codegen keeps the language-level story simple: the
programmer just writes a capturing closure exactly like they would
anywhere else in Vertex, and the FFI boundary is invisible.