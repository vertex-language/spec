# ir/objc, ir/cpp, and ir/c — Independent Pipelines

## Overview

`ir/objc`, `ir/cpp`, and `ir/c` are three fully independent compilation pipelines. Each owns its full path from frontend to object file. They do not share a node tree. They meet at the linker.

The connection between them is not manual. The compiler reads all Native Interface declarations across all active pipelines and generates **ir/c bindings** — glue code in ir/c that interconnects functions and methods across language boundaries. The developer imports a package and calls methods. Nothing else is required.

---

## The Three Pipelines

```
Vertex frontend
        │
        ├── Native Interface (ObjC)
        │           │
        │           ▼
        │       ir/objc
        │   classes · selectors · ARC
        │   blocks · protocols · GCD
        │           │
        │       mir/objc
        │   msgSend variants · ARC injection
        │   block materialization · stret
        │   __objc_* metadata sections
        │           │
        │       encoder/amd64
        │           │
        │           ▼
        │       uikit.o ───────────────────────┐
        │                                      │
        ├── Native Interface (C++)             │
        │           │                          │
        │           ▼                          │
        │       ir/cpp                         │
        │   vtables · mangling · RAII          │
        │   templates · exceptions             │
        │           │                          │
        │       mir/cpp                        │
        │   vtable construction · dispatch     │
        │   ctor/dtor ordering · .eh_frame     │
        │   .init_array / __mod_init_func      │
        │           │                          │
        │       encoder/amd64                  │
        │           │                          │
        │           ▼                          │
        │       d3d11.o ────────────────────── ┤
        │                                      │
        └── Normal source (C / Vertex)         │
                    │                          │
                ir/c                           │
            structs · ABI · calling conventions│
                    │                          │
                ir/mir                         │
                    │                          │
                encoder/amd64                  │
                    │                          │
                    ▼                          │
                app.o ─────────────────────────┤
                                               │
                   ir/c generated bindings ────┤
               (compiler-generated glue;       │
                interconnects functions and    │
                methods across pipelines)      │
                                               │
                                          linker
                                               │
                                        executable
```

---

## Native Interfaces — The Typed Contract

A Native Interface is a bridge package file. It declares foreign class signatures in Vertex's type system and is the single source of truth the compiler uses to understand what lives on the other side of a language boundary.

```swift
/* uikit.vs — Native Interface for UIKit (ObjC pipeline) */
package uikit
build darwin
import "darwin/objc/uikit"

struct CGFloat = float64
struct CGPoint { x: CGFloat, y: CGFloat }
struct CGSize  { w: CGFloat, h: CGFloat }
struct CGRect  { origin: CGPoint, size: CGSize }

class UIColor : uikit {
    func red()   -> UIColor
    func blue()  -> UIColor
    func green() -> UIColor
    func colorWithRed(
        r: CGFloat, green: CGFloat,
        blue: CGFloat, alpha: CGFloat) -> UIColor
}

class UIView : uikit {
    func initWithFrame(self: UIView, frame: CGRect) -> UIView
    func addSubview(self: UIView, view: UIView)
    func setBackgroundColor(self: UIView, color: UIColor)
    func setAlpha(self: UIView, alpha: CGFloat)
    func bounds(self: UIView) -> CGRect
    func setNeedsLayout(self: UIView)
}

class UILabel : UIView {
    func setText(self: UILabel, text: string)
    func setTextColor(self: UILabel, color: UIColor)
}
```

```swift
/* d3d11.vs — Native Interface for Direct3D 11 (C++ pipeline) */
package d3d11
build windows
import "windows/com/d3d11"

class IUnknown : d3d11 {
    func QueryInterface(
        obj: IUnknown,
        riid: any opaque,
        ppv: mut any opaque) -> int
    func AddRef(obj: IUnknown) -> uint
    func Release(obj: IUnknown) -> uint
}

class ID3D11Device : IUnknown {
    func CreateBuffer(
        d: ID3D11Device,
        desc: mut any opaque,
        init: mut any opaque,
        ppBuffer: mut any opaque) -> int
    func CreateTexture2D(
        d: ID3D11Device,
        desc: mut any opaque,
        init: mut any opaque,
        ppTexture: mut any opaque) -> int
}
```

These files are written once, live in the standard library or a package repository, and never change for a given platform SDK version. The developer never opens them.

---

## ir/c Generated Bindings

When a Vertex type meets a foreign type at a call site, the compiler reads the relevant Native Interface declarations and generates ir/c bindings — glue code in ir/c that forms the concrete connection between pipelines. These bindings are themselves compiled through the ir/c → ir/mir → encoder path and linked in alongside the other object files.

### What the bindings handle

| Vertex type meets | ir/c binding generates |
|---|---|
| `string` → ObjC method param | `NSString` via `stringWithUTF8String` |
| `[T]` → ObjC method param | `NSArray` via `arrayWithObjects:count:` |
| `[K:V]` → ObjC method param | `NSDictionary` via `dictionaryWithObjects:forKeys:count:` |
| Vertex closure → ObjC block param | `Block_literal` struct, invoke pointer, capture fields |
| ObjC object → Vertex use site | Transparent opaque pointer, no conversion |
| Vertex struct → C struct param | Direct field mapping, no conversion |
| `string` → C++ `std::string` param | Constructor call `std::string(ptr, len)` |
| Vertex closure → C++ `std::function` | Wrapper object construction |

### Example — string to NSString

When the developer writes:

```swift
label.setText("hello world")
```

The compiler sees that `UILabel.setText` expects `NSString *` and the argument is a Vertex `string`. It emits an ir/c binding:

```c
/* ir/c binding — generated, never written by hand */
void __bind_UILabel_setText(UILabel *self, vertex_string s) {
    NSString *__ns = ((NSString *(*)(Class, SEL, const char *))objc_msgSend)(
        objc_getClass("NSString"),
        sel_registerName("stringWithUTF8String:"),
        s.ptr);
    ((void (*)(id, SEL, NSString *))objc_msgSend)(
        (id)self,
        sel_registerName("setText:"),
        __ns);
}
```

The developer wrote `label.setText("hello world")`. That is all they wrote.

### Example — closure to ObjC block

When a closure is passed where a Native Interface declares a block parameter:

```swift
uikit.UIView.animate(duration: 0.3) {
    label.setAlpha(1.0)
}
```

The ir/c binding materializes the full block struct:

```c
/* ir/c binding — Block_literal for the closure */
struct __block_literal_0 {
    void *isa;           /* _NSConcreteStackBlock */
    int   flags;
    int   reserved;
    void (*invoke)(struct __block_literal_0 *);
    UILabel *__cap_label; /* captured variable */
};

static void __block_invoke_0(struct __block_literal_0 *__b) {
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(
        (id)__b->__cap_label,
        sel_registerName("setAlpha:"),
        1.0);
}
```

None of this is visible at the call site.

### Linker flags

The ir/c bindings layer also resolves which runtime libraries the linker needs. If `uikit.vs` is active, `-lobjc -framework UIKit` is added. If `d3d11.vs` is active, `d3d11.lib` is added. The developer does not write linker flags.

---

## What Each Pipeline Owns

### ir/c → ir/mir → encoder → .o

All normal Vertex source. All C stdlib and POSIX surfaces via the C header parser. Structs, calling conventions, ABI enforcement, volatile/atomic semantics. Also the target for all generated ir/c bindings — they compile through this same path.

### ir/objc → mir/objc → encoder → .o

| Concern | How mir/objc handles it |
|---|---|
| `objc_msgSend` dispatch | Selects plain / `_stret` / `_fpret` variant from return type |
| ARC retain/release | Injected at assignment sites and scope exits |
| Block structs | Built from closure body and capture list, invoke pointer generated |
| `__block` captures | `Block_byref` struct, `forwarding` pointer rewrite |
| `@autoreleasepool` | `objc_autoreleasePoolPush` / `Pop` with correct pairing on all paths |
| `@synchronized` | `objc_sync_enter` / `objc_sync_exit` with cleanup on all exits |
| Weak references | `objc_initWeak` / `objc_storeWeak` / `objc_destroyWeak` |
| Metadata sections | `__objc_classlist`, `__objc_methnames`, `__objc_selrefs`, `__objc_protolist` |

### ir/cpp → mir/cpp → encoder → .o

| Concern | How mir/cpp handles it |
|---|---|
| Vtable structs | Function pointer fields in declaration order; child prepends parent |
| Virtual dispatch | Load through `__vptr` + indirect call |
| Name mangling | Itanium or MSVC scheme selected from bound target |
| Constructor/destructor | `__vptr` assigned first; base chain ordered by mir/cpp |
| Static constructors | Entries in `.init_array` / `__mod_init_func` sections |
| Exception tables | `.eh_frame` / `__unwind_info` DWARF records per function |
| RTTI | `type_info` global, pointer in vtable prefix |

COM note: COM vtable dispatch is C-compatible. mir/cpp emits COM dispatch as a plain function pointer load — no C++ runtime library required for COM-only use.

---

Looking at the grammar carefully — no `self`, no inheritance, struct literals use brace syntax, anonymous functions use `func()` form, receiver syntax for associated functions. Here's the corrected Consumer Experience:

---

## Consumer Experience

```swift
import "uikit"

func buildLabel(view: uikit.UIView) {

    var ui    = uikit.UILabel()
    var color = uikit.UIColor()

    let frame = uikit.CGRect{
        origin: uikit.CGPoint{x: 0.0, y: 0.0},
        size:   uikit.CGSize{w: 300.0, h: 50.0}
    }

    let label = ui.initWithFrame(frame)

    label.setText("hello world")        // string — ir/c binding bridges to NSString
    label.setTextColor(color.blue())    // class-side — color is dispatch surface only

    view.addSubview(label)

    uikit.UIView.animate(duration: 0.4, animations: func() {
        label.setAlpha(1.0)             // label captured by value at creation
    })
}
```

```swift
import "d3d11"

func initBuffers(device: d3d11.ID3D11Device) -> int {

    var desc = d3d11.BufferDesc{
        ByteWidth:      256,
        Usage:          d3d11.UsageDefault,
        BindFlags:      d3d11.BindConstantBuffer,
        CPUAccessFlags: 0
    }

    var buf: d3d11.ID3D11Buffer? = nil
    let hr = device.CreateBuffer(desc.any(), nil, &buf)
    return hr
}
```

Key corrections from the previous version:

- Struct literals use `TypeName{field: value}` not `TypeName(field: value)`
- Anonymous function passed as block param uses `func() { }` not bare `{ }` — closures aren't a separate syntax in Vertex
- No `class MyViewController : uikit.UIViewController` — inheritance is removed from the language
- No `self` anywhere — receiver is either an explicit named param or absent
- `color.blue()` is valid because `color` is the zero-size dispatch surface and `blue()` has no first typed receiver param

---

## Platform Matrix

| Platform | ir/c | ir/objc | ir/cpp | ir/c bindings add |
|---|---|---|---|---|
| Darwin macOS / iOS | ✓ | ✓ | optional | `-lobjc -lc++` + framework flags from active Native Interfaces |
| Linux | ✓ | GNUstep | ✓ | `objc_init()` constructor at priority 101 + `-lgnustep-base` |
| Windows | ✓ | — | ✓ COM | `.lib` dependencies from active Native Interfaces |
| Bare metal | ✓ | — | — | No bindings generated; `metal/` Native Interfaces handle everything |

---

## Summary

| Concept | What it is |
|---|---|
| Native Interface | Bridge package file — declares foreign class signatures as Vertex types |
| ir/c generated bindings | Compiler-generated ir/c glue that interconnects functions and methods across pipelines |
| `string` → `NSString` | ir/c binding handles the conversion — developer writes `string` |
| Closure → ObjC block | ir/c binding materializes `Block_literal` from the closure |
| ObjC object passing | Transparent — opaque pointer, no conversion |
| COM vtable dispatch | Transparent — C-compatible function pointer load |
| Runtime init sections | Emitted by mir/objc / mir/cpp into `.o` — developer never touches |
| Linker flags | Resolved from active Native Interface declarations, emitted with the bindings |
| Developer experience | Import a package. Call methods. Everything else is automatic. |