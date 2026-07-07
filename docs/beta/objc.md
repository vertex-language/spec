# Vertex Native ObjC Lowering — Overview (v3)

> **ABI Matching — No C Headers Required**
> By emitting directly to the ObjC runtime ABI, Vertex bypasses the entire
> C header layer completely. Selectors are computed from binding declarations
> via `selectorForMethod()`, and dispatch is handled through the three core
> runtime signatures:
>
> ```
> objc_getClass      — resolves a class by name from the global class table
> objc_msgSend       — dispatches a message to any receiver via SEL
> sel_registerName   — interns a selector string into the runtime
> ```
>
> These three symbols are all that's needed. No `#import`, no umbrella headers,
> no SDK parsing. The Vertex binding declaration replaces the header entirely.

---

## ObjC Memory Model — Why `.new()` Maps Perfectly

Objective-C has been ARC (Automatic Reference Counting) since 2011. It is the
entire memory model for the darwin framework ecosystem. Every `NSObject`
subclass — which is essentially everything in AppKit, Foundation, UIKit, and
WebKit — is ref counted at the runtime level:

```
alloc         → count = 1
retain        → count + 1
release       → count - 1 → if 0: dealloc called automatically
```

Vertex `.new()` maps to this 1:1:

| Vertex `.new()` | ObjC ARC |
|---|---|
| `Type(...).new()` construction | `alloc+init` → count = 1 |
| scope exit | `objc_release` → count - 1 → `dealloc` if 0 |
| `weak let` | `objc_storeWeak` / `objc_loadWeak` |

This is why `.new()` is the right signal for darwin classes — not a hack,
not a special case. ObjC IS ref counted. Vertex RC and ObjC ARC are the same
mental model. The only difference is the backend wiring.

### The Three Exceptions

Not all ObjC objects follow standard ARC. These three categories exist and
are handled by **not** using `.new()`:

**1. Singletons** — classes where you never own the instance, never release it:
```vertex
// NSApplication, NSNotificationCenter, NSFileManager etc
var app    = NSApplication()           // no .new() — you don't own it
let shared = app.sharedApplication()   // singleton returned by class method
```

**2. CoreFoundation types** — `CFStringRef`, `CFArrayRef`, `CGContextRef` etc.
These use a parallel RC system (`CFRetain`/`CFRelease`) that is distinct from
`objc_retain`/`objc_release`. They are bound via `darwin/lib/CoreFoundation`
not `darwin/framework/` and treated as plain C pointers.

**3. Tagged pointers** — small integers and short strings that ObjC packs
directly into the pointer value itself. No heap allocation, `release` is a
no-op. Fully transparent — the runtime handles it, Vertex never sees it.

### What This Means in Practice

For everything you touch in AppKit, Foundation, WebKit, UIKit — the vast
majority of darwin framework code — `.new()` = ObjC ARC is correct and
complete. The design is not an approximation. It is an exact match to how
ObjC manages memory for the frameworks Vertex targets.

---

## Construction Model — v1/v2 vs v3

### v1/v2 (current — deprecated)

The original approach used an empty receiver function body as a compiler signal
that a darwin class supports `alloc+init` construction. This was a hack:

```vertex
// v2 — empty body is the signal, ugly and confusing
func (w: NSWindow) init() {}
func (s: NSString) init() {}
func (a: NSApplication) init() {}   // problem: NSApplication is a singleton!

auto var window = NSWindow(initWithContentRect: rect, styleMask: 15, backing: 2, defer: false)
auto var title  = NSString(initWithUTF8String: "Hello")
```

Problems with v2:
- Empty function body as a compiler signal is a hack — not real syntax
- `auto var` must be remembered manually for every darwin object
- `auto var` on a singleton (NSApplication) would wrongly call objc_release
- Two separate concepts (construction signal + memory management) with no
  unified mental model
- Nothing in the type system tells you whether a class is constructable or
  a singleton

### v3 (proposed — this document)

`.new()` is the unified signal. It means:
- "This class supports direct construction via alloc+init"
- "Wire ObjC retain/release, not malloc/free, for my lifetime"
- Scope exit → `objc_release` emitted automatically — no `auto`, no `defer`

```vertex
// v3 — .new() is the complete signal
var window = NSWindow(initWithContentRect: rect, styleMask: 15, backing: 2, defer: false).new()
var title  = NSString(initWithUTF8String: "Hello").new()

// singleton — no .new(), just call class methods directly
var app    = NSApplication()
let shared = app.sharedApplication()
```

No empty init body. No `auto`. No `defer`. The distinction between
constructable classes and singletons is explicit at the call site.

---

## Core Concept — Everything is a Normal Object

Darwin-bound classes in Vertex behave like any other class. No `self` parameter
in binding declarations, no class-method vs instance-method distinction exposed
to the user. You construct an object, you call methods on it.

```vertex
import "darwin/framework/Foundation"

class NSURL : Foundation {
    func URLWithString(string: *const char) -> NSURL
    func absoluteString() -> *const char
    func path() -> *const char
}

var url  = NSURL().new()
var full = url.URLWithString(string: "https://example.com")
let p    = full.path()
// scope exits → objc_release(url), objc_release(full) emitted automatically
```

---

## What `.new()` Does on a Darwin Class

For non-darwin classes, `.new()` wires Vertex RC:
- allocation → `malloc`
- release    → `free()`

For darwin classes, `.new()` detects `isDarwinCls` and wires ObjC RC:
- allocation → `objc_getClass` + `alloc` + resolved `init` selector
- retain     → `objc_retain` (implicit, on construction)
- release    → `objc_msgSend(obj, sel_registerName("release"))` at scope exit

The caller writes identical code. The compiler routes to the right backend.

```vertex
// non-darwin — malloc + free
var animal = Animal(name: "Rex").new()

// darwin — alloc+init + objc_retain + objc_release
var window = NSWindow(initWithContentRect: rect, styleMask: 15, backing: 2, defer: false).new()
```

---

## Singleton Classes — No `.new()`

Some ObjC classes are singletons or factory-only. You never `alloc+init` them.
Without `.new()` the compiler emits a phantom `i32` placeholder and you call
class methods directly:

```vertex
class NSApplication : AppKit {
    func sharedApplication() -> NSApplication
    func run()
    func setActivationPolicy(policy: int32)
    func activateIgnoringOtherApps(flag: bool)
}

// no .new() — singleton, no alloc+init
var app    = NSApplication()
let shared = app.sharedApplication()
shared.setActivationPolicy(policy: 0)
shared.run()
```

The distinction is natural — if you want ObjC RC managed lifetime, write
`.new()`. If you don't, you're treating the binding as a phantom handle for
class method dispatch.

---

## Init Selector Resolution

When `.new()` is present, the compiler resolves the init selector from the
call-site arguments by matching labels against binding declarations prefixed
with `init`:

| Call site | Emitted ObjC |
|---|---|
| `NSWindow().new()` | `alloc` + `init` |
| `NSWindow(initWithContentRect: r, styleMask: m, backing: b, defer: d).new()` | `alloc` + `initWithContentRect:styleMask:backing:defer:` |
| `NSString(initWithUTF8String: s).new()` | `alloc` + `initWithUTF8String:` |

Zero-arg `.new()` always falls back to `alloc+init`.

---

## Binding Declarations — No `self`, No Class/Instance Split

```vertex
class NSWindow : AppKit {
    func initWithContentRect(contentRect: NSRect, styleMask: uint32, backing: uint32, defer: bool) -> NSWindow
    func makeKeyAndOrderFront(sender: *const void)
    func setTitle(aString: NSString)
    func center()
}

class NSString : Foundation {
    func initWithUTF8String(nullTerminatedCString: *const char) -> NSString
    func UTF8String() -> *const char
    func length() -> int32
}
```

No `self`. No class/instance annotation. The compiler emits `objc_msgSend`
with the object as receiver for every method call.

---

## Selector Generation

```
method name + each param label + ":" per label present

func initWithContentRect(contentRect, styleMask, backing, defer)  →  "initWithContentRect:styleMask:backing:defer:"
func initWithUTF8String(nullTerminatedCString)                    →  "initWithUTF8String:"
func makeKeyAndOrderFront(sender)                                  →  "makeKeyAndOrderFront:"
func setTitle(aString)                                             →  "setTitle:"
func goBack()                                                      →  "goBack"
func run()                                                         →  "run"
```

---

## Import Path Conventions

| Import path | What it means | Lowering |
|---|---|---|
| `darwin/framework/X` | ObjC framework | ObjC runtime — `objc_msgSend`, selectors, `.new()` = alloc+init |
| `darwin/lib/X` | Plain C library on Darwin | Direct C extern calls |
| `linux/lib/X` | Plain C library on Linux | Direct C extern calls |

---

## Memory Model

| Pattern | Allocation | Release | When |
|---|---|---|---|
| `var x = DarwinClass().new()` | `alloc+init` | `objc_release` | scope exit |
| `var x = DarwinClass()` (singleton) | phantom i32 | none | never |
| `var x = VertexClass().new()` | `malloc` | `free()` | scope exit |
| `var x = VertexClass()` | `malloc` | manual `.delete()` | caller |

`.new()` on a darwin class = ObjC ARC.
`.new()` on a vertex class = Vertex RC.
Same syntax, right backend wired automatically.

---

## Compiler Changes from v2 → v3

### `expr.go` — `constructClass`

```
if isDarwinCls && postfix .new():
    emit alloc+init (existing emitObjcAlloc logic)
    emit objc_retain
    register for scope-exit objc_release
    return ptrVT

if isDarwinCls && no .new():
    emit phantom i32 (existing singleton path)
    return i32VT
```

### `stmt.go` — scope exit

```
if isDarwinCls && was constructed with .new():
    emit objc_msgSend(obj, sel_registerName("release"))
```

No change needed to `emitAutoDelete` — it already routes darwin classes
to `emitObjcRelease`. The difference is it now triggers from `.new()` scope
tracking rather than `auto var`.

### Removed

- `initCls map[string]bool` — no longer needed
- Empty `func (r: T) init() {}` body detection in `declareFuncs`
- `auto var` requirement for darwin objects

---

## Full Example — NSWindow

```vertex
package main

import "darwin/framework/AppKit"
import "darwin/framework/Foundation"

struct NSRect {
    x:      float64
    y:      float64
    width:  float64
    height: float64
}

class NSApplication : AppKit {
    func sharedApplication() -> NSApplication
    func run()
    func setActivationPolicy(policy: int32)
    func activateIgnoringOtherApps(flag: bool)
}

class NSWindow : AppKit {
    func initWithContentRect(contentRect: NSRect, styleMask: uint32, backing: uint32, defer: bool) -> NSWindow
    func makeKeyAndOrderFront(sender: *const void)
    func setTitle(aString: NSString)
    func center()
}

class NSString : Foundation {
    func initWithUTF8String(nullTerminatedCString: *const char) -> NSString
}

func main() -> int32 {
    // singleton — no .new()
    var app    = NSApplication()
    let shared = app.sharedApplication()
    shared.setActivationPolicy(policy: 0)

    let rect = NSRect(x: 200.0, y: 200.0, width: 600.0, height: 400.0)

    // .new() = alloc+init + ObjC ARC — objc_release at scope exit automatically
    var window = NSWindow(
        initWithContentRect: rect,
        styleMask: 15,
        backing: 2,
        defer: false
    ).new()

    var title = NSString(initWithUTF8String: "Hello from Vertex").new()

    window.setTitle(aString: title)
    window.center()
    window.makeKeyAndOrderFront(sender: nil)

    shared.activateIgnoringOtherApps(flag: true)
    shared.run()

    return 0
}
```

Clean. No empty init bodies. No `auto var`. No `defer`.
`.new()` is the complete signal for construction + ObjC ARC lifetime.

---

## Grammar Signal Summary

| ObjC concept | Vertex grammar signal |
|---|---|
| Framework binding | `import "darwin/framework/X"` |
| Constructable class + ObjC ARC | `Type(...).new()` |
| Singleton / factory class | `Type()` with no `.new()` |
| Named init selector | `Type(initWithX: ...)` — labels matched to binding |
| Default init | `Type().new()` — emits `alloc+init` |
| Nil argument | `nil` to any `T?` param |
| ObjC release at scope exit | automatic from `.new()` |
| Weak reference | `weak let` binding |
| Protocol impl | `class MyClass : Framework.ProtocolName` |
| `dealloc` | `deinit` on darwin-bound class |