# Vertex Native ObjC Lowering — Overview

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
> no SDK parsing. The Vertex binding declaration replaces the header entirely —
> it is the source of truth for selector generation and type dispatch.
> The linker only needs the `.dylib` paths for `LC_LOAD_DYLIB` entries, nothing more.

> Note: C snippets in this document are illustrative only —
> showing what the VIR semantically represents in a familiar form.
> Vertex does not emit C. The actual pipeline is:
> Vertex → VIR → Machine IR → Machine Code

---

## Core Concept — Everything is a Normal Object

Darwin-bound classes in Vertex behave like any other class. No `self` parameter
in binding declarations, no class-method vs instance-method distinction exposed
to the user. You construct an object, you call methods on it.

```vertex
import "darwin/framework/Foundation"

class NSURL : Foundation {
    func URLWithString(string: *const char) -> NSURL?
    func absoluteString() -> *const char
    func path() -> *const char
}

// No special init — compiler emits alloc+init automatically
var url = NSURL()
let result = url.URLWithString(string: "https://example.com")
let p      = url.path()
```

The compiler always emits `alloc+init` for `Type()` construction of a
darwin-bound class. The binding declarations carry no `self` parameter —
the receiver is implicit, exactly like any other Vertex class method.

---

## Custom Init Selectors

When construction requires arguments (e.g. `initWithFrame:configuration:`),
declare a `func (receiver: T) init()` body. Its presence tells the compiler
which `init`-prefixed binding method to match against the call args.

```vertex
import "darwin/framework/WebKit"

class WKWebView : WebKit {
    func initWithFrame(frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView
    func loadHTMLString(string: *const char, baseURL: NSURL?)
    func goBack()
}

func (wk: WKWebView) init() {}   // signals: alloc + resolve init selector from call args

// Compiler sees WKWebView() → alloc + init
// Compiler sees WKWebView(initWithFrame: r, configuration: c) → alloc + initWithFrame:configuration:
var w  = WKWebView()
var w2 = WKWebView(initWithFrame: myRect, configuration: cfg)
w2.loadHTMLString(string: html, baseURL: nil)
w2.goBack()
```

Without the `func (wk: WKWebView) init() {}` body, `WKWebView()` is a compile
error — the compiler has no init selector to emit. The body itself is empty
and generates no code; its presence is the signal only.

---

## Init Selector Resolution

When a `func (r: T) init()` body is present, the compiler resolves the init
selector from the call-site arguments by matching labels against binding
declarations prefixed with `init`:

| Call site | Emitted ObjC selector |
|---|---|
| `WKWebView()` | `alloc` + `init` |
| `WKWebView(initWithFrame: r, configuration: c)` | `alloc` + `initWithFrame:configuration:` |
| `WKWebView(initWithCoder: c)` | `alloc` + `initWithCoder:` |

Selector generation: method name + each param label + `:` per label present.

```
func initWithFrame(frame, configuration)  →  "initWithFrame:configuration:"
func initWithCoder(coder)                 →  "initWithCoder:"
```

---

## Binding Declarations — No `self`, No Class/Instance Split

Binding methods inside a darwin-bound class are always instance methods from
Vertex's perspective. The compiler emits `objc_msgSend` with the object as
receiver for every method call. There is no annotation needed to distinguish
class methods — if the underlying ObjC method is a class method (like
`URLWithString` on NSURL), you simply call it on the allocated instance and
the ObjC runtime handles it correctly via the class's method table.

```vertex
// Binding declaration — clean, no self, no noise
class NSURL : Foundation {
    func URLWithString(string: *const char) -> NSURL?
    func URLWithString(string: *const char, relativeToURL: NSURL?) -> NSURL?
    func absoluteString() -> *const char
    func path() -> *const char
    func host() -> *const char
}

var url  = NSURL()
var full = url.URLWithString(string: "https://example.com")
var rel  = url.URLWithString(string: "/api", relativeToURL: full)
```

---

## Selector Generation — Deterministic from Declaration

```
method name + each param label + ":" per label

func URLWithString(string)                       →  "URLWithString:"
func URLWithString(string, relativeToURL)        →  "URLWithString:relativeToURL:"
func initWithFrame(frame, configuration)         →  "initWithFrame:configuration:"
func loadHTMLString(string, baseURL)             →  "loadHTMLString:baseURL:"
func goBack()                                    →  "goBack"
```

Computed in `runtime_objc.go` by `selectorForMethod()` and interned as a
passive data segment via `internSelectorLit`.

---

## Import Path Conventions

| Import path | What it means | Lowering |
|---|---|---|
| `darwin/framework/X` | ObjC framework (AppKit, UIKit, WebKit, etc.) | ObjC runtime — `objc_msgSend`, selectors, alloc+init |
| `darwin/lib/X` | Plain C library on Darwin (CoreGraphics, libc, etc.) | Direct C extern calls |
| `linux/lib/X` | Plain C library on Linux | Direct C extern calls |

`darwin/framework/` is the sole signal for ObjC runtime lowering. Everything
else is a direct C call.

---

## How It Fits in the vir Package

No new passes. Hooks into the four existing phases `NewLower` already runs:

```
NewLower
    declareTypes()      ← detects darwin-bound class decls, populates isDarwinCls
    declareExterns()    ← registers binding methods via resolveImportLib
    declareRuntime()    ← injects objc_getClass / objc_msgSend / sel_registerName
    declareFuncs()      ← detects func (r: T) init() bodies, records initCls map
    declareGlobals()    ← unchanged
    lowerBodies()
        frame.call()         ← WKWebView(...) → emitObjcAlloc
        frame.methodCall()   ← w.goBack()     → emitObjcCall
```

Two files added:

```
vir/
    runtime_objc.go     ← declareObjcRuntime(), internSelectorLit(), selectorForMethod()
    lower_objc.go       ← emitObjcCall(), emitObjcAlloc()
```

---

## Stage 1 — Vertex Source Examples

### NSURL — no custom init needed
```vertex
import "darwin/framework/Foundation"

class NSURL : Foundation {
    func URLWithString(string: *const char) -> NSURL?
    func absoluteString() -> *const char
    func path() -> *const char
}

var url     = NSURL()
var result  = url.URLWithString(string: "https://example.com")
let p       = result.path()
```

### WKWebView — custom init selector
```vertex
import "darwin/framework/WebKit"

class WKWebView : WebKit {
    func initWithFrame(frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView
    func loadHTMLString(string: *const char, baseURL: NSURL?)
    func goBack()
    func goForward()
}

func (wk: WKWebView) init() {}

var w = WKWebView(initWithFrame: myRect, configuration: cfg)
w.loadHTMLString(string: html, baseURL: nil)
w.goBack()
```

### NSString — multiple init selectors
```vertex
import "darwin/framework/Foundation"

class NSString : Foundation {
    func initWithUTF8String(nullTerminatedCString: *const char) -> NSString
    func initWithFormat(format: *const char) -> NSString
    func UTF8String() -> *const char
    func length() -> int32
}

func (s: NSString) init() {}

var s1 = NSString(initWithUTF8String: "hello")
var s2 = NSString(initWithFormat: "%d items")
let cs = s1.UTF8String()
```

---

## Stage 2 — What declareObjcRuntime() Injects

`runtime_objc.go` mirrors `runtime_arrays.go` — pure declarations, no emit logic:

```go
func (l *Lower) declareObjcRuntime() {
    ptr := vertex.Ptr()

    reg := func(name string, ft vertex.FuncType) {
        l.funcIdx["objc_."+name] = l.mod.Imports.ImportFunc(
            "darwin:libobjc.dylib", name, l.mod.Types.AddFunc(ft))
    }

    reg("objc_getClass",
        vertex.FuncType{
            Params:  []vertex.Param{{Type: ptr}},
            Results: []vertex.ValType{ptr},
        })
    reg("objc_msgSend",
        vertex.FuncType{
            Variadic: true,
            Params:   []vertex.Param{{Type: ptr}, {Type: ptr}},
            Results:  []vertex.ValType{ptr},
        })
    reg("sel_registerName",
        vertex.FuncType{
            Params:  []vertex.Param{{Type: ptr}},
            Results: []vertex.ValType{ptr},
        })
    reg("objc_storeWeak",
        vertex.FuncType{
            Params: []vertex.Param{{Type: ptr}, {Type: ptr}},
        })
    reg("objc_loadWeak",
        vertex.FuncType{
            Params:  []vertex.Param{{Type: ptr}},
            Results: []vertex.ValType{ptr},
        })

    l.mod.Imports.ImportGlobal(
        "darwin:libSystem.dylib", "_NSConcreteStackBlock",
        vertex.GlobalType{Mut: false, Type: ptr})
}
```

`declareRuntime` in `decl.go` calls this under a target guard:

```go
func (l *Lower) declareRuntime() {
    if l.pkg.Name == "arrays" {
        return
    }
    l.declareArrayRuntime()
    if strings.HasPrefix(l.target, "darwin") {
        l.declareObjcRuntime()
    }
}
```

---

## Stage 3 — Init Body Detection

`declareFuncs()` in `decl.go` already walks all `FuncDecl` nodes. When a
receiver function named `init` is found on a darwin-bound class, it is
recorded in `l.initCls`:

```go
// decl.go — inside declareFuncs(), existing receiver func loop
if fd.Receiver != nil && fd.Name == "init" {
    typeName := recvTypeName(fd.Receiver.Type)
    if l.isDarwinCls[typeName] {
        l.initCls[typeName] = true   // alloc+init injection is valid
        // no VIR function body emitted — signal only
        continue
    }
}
```

`initCls map[string]bool` lives on `Lower` alongside `isDarwinCls`.

---

## Stage 4 — emitObjcAlloc (lower_objc.go)

Called from `frame.constructClass` in `expr.go` when `isDarwinCls` is true.

```go
func (f *frame) emitObjcAlloc(className string, x *ast.CallExpr) vtype {
    if !f.l.initCls[className] {
        f.errorf(x.Pos(), "cannot construct %q: no init body declared", className)
        f.b.PtrNull()
        return ptrVT
    }

    getClass := f.l.funcIdx["objc_.objc_getClass"]
    msgSend  := f.l.funcIdx["objc_.objc_msgSend"]
    selReg   := f.l.funcIdx["objc_.sel_registerName"]

    clsDat   := f.l.internSelectorLit(className)
    allocDat := f.l.internSelectorLit("alloc")

    // objc_getClass("ClassName")
    f.b.DataAddr(clsDat)
    f.b.Call(getClass)
    clsLoc := f.newLocal(ptrVT)
    f.b.LocalSet(clsLoc)

    // alloc
    f.b.LocalGet(clsLoc)
    f.b.DataAddr(allocDat)
    f.b.Call(selReg)
    allocSelLoc := f.newLocal(ptrVT)
    f.b.LocalSet(allocSelLoc)
    f.b.LocalGet(clsLoc)
    f.b.LocalGet(allocSelLoc)
    f.b.Call(msgSend)
    objLoc := f.newLocal(ptrVT)
    f.b.LocalSet(objLoc)

    // resolve init selector from call args
    initSel, initMethod := f.l.resolveInitSelector(className, x)
    initDat := f.l.internSelectorLit(initSel)

    f.b.LocalGet(objLoc)
    f.b.DataAddr(initDat)
    f.b.Call(selReg)
    initSelLoc := f.newLocal(ptrVT)
    f.b.LocalSet(initSelLoc)
    f.b.LocalGet(objLoc)
    f.b.LocalGet(initSelLoc)
    if initMethod != nil {
        sig := f.l.methodSig[className+"."+initMethod.Name]
        f.pushArgs(x.Args, sig, 0)
    }
    f.b.Call(msgSend)

    return ptrVT
}
```

`resolveInitSelector` in `runtime_objc.go` scans the class's binding methods
for one prefixed with `init` whose param labels match the call args, falling
back to `"init"` for zero-arg construction.

---

## Stage 5 — emitObjcCall (lower_objc.go)

Called from `frame.methodCall` in `expr.go` when `isDarwinCls` is true.

```go
func (f *frame) emitObjcCall(recvVT vtype, methodName string, x *ast.CallExpr) vtype {
    msgSend := f.l.funcIdx["objc_.objc_msgSend"]
    selReg  := f.l.funcIdx["objc_.sel_registerName"]

    cd := f.l.classDecls[recvVT.name]
    m  := f.l.findMethod(cd, methodName)
    if m == nil {
        f.errorf(x.Pos(), "no binding method %q on darwin class %s", methodName, recvVT.name)
        f.b.I32Const(0)
        return i32T
    }

    sel    := selectorForMethod(m)
    selDat := f.l.internSelectorLit(sel)

    // Register selector
    f.b.DataAddr(selDat)
    f.b.Call(selReg)
    selLoc := f.newLocal(ptrVT)
    f.b.LocalSet(selLoc)

    // Push receiver (always an instance — the allocated object)
    f.expr(x.Fun.(*ast.SelectorExpr).X, &recvVT)

    // Push SEL
    f.b.LocalGet(selLoc)

    // Push args
    sig := f.l.methodSig[recvVT.name+"."+methodName]
    f.pushArgs(x.Args, sig, 0)

    f.b.Call(msgSend)

    return f.l.objcReturnVType(m)
}
```

---

## Stage 6 — VIR Output

The compiled module contains only three undefined symbols:

```
_objc_getClass
_objc_msgSend
_sel_registerName
```

The Vertex linker emits `LC_LOAD_DYLIB` entries:

```
LC_LOAD_DYLIB  /usr/lib/libobjc.dylib
LC_LOAD_DYLIB  /System/Library/Frameworks/WebKit.framework/WebKit
```

---

## Stage 7 — Runtime Boot Sequence

```
kernel maps Mach-O into memory
    → dyld reads LC_LOAD_DYLIB entries
    → maps libobjc into process
    → maps framework into process
    → ObjC runtime initializers fire
    → main() runs
    → WKWebView() → objc_getClass → alloc → initWithFrame:configuration:
    → w.goBack()  → objc_msgSend(w, "goBack")
```

---

## Stage 8 — Code Signing

```go
exe, err    := l.Link()
signed, err := codesign.SignImage(exe, codesign.Options{Identifier: "myapp"})
os.WriteFile("myapp", signed, 0755)
```

Apple Silicon requires a valid signature — the kernel rejects unsigned
binaries before `main` is reached.

---

## Memory — `auto` and `weak let`

`auto` on a darwin-bound class lowers to `objc_msgSend(obj, sel_release)`
rather than `RcRelease`. `weak let` lowers to `objc_storeWeak` /
`objc_loadWeak`. Both are handled in `emitAutoDelete` in `stmt.go`:

```go
if f.l.isDarwinCls[vt.name] {
    f.b.LocalGet(loc)
    f.emitSelCall("release", loc, vt, nil)
    return
}
```

---

## Blocks — Anonymous Functions

When a binding method declares a parameter of function type, `emitObjcCall`
detects it via the param's `vtype.isRef` and func type index, then emits a
block struct (isa + invoke + descriptor + captured env) rather than a raw
funcref. The anonymous function literal is the signal — no new syntax.

---

## Delegates / Protocols

A Vertex class declared with a darwin protocol parent becomes an ObjC
protocol implementation. `declareTypes` records it in `protocolImpls`. A
startup function (`emitObjcStartup` in `lower_objc.go`) is injected before
`main` and calls `objc_allocateClassPair` / `class_addMethod` /
`objc_registerClassPair` for each registered protocol impl.

```vertex
import "darwin/framework/WebKit"

class MyNavDelegate : WebKit.WKNavigationDelegate {
    func webView(didFinishNavigation: WKNavigation?)
}

func (d: MyNavDelegate) webView(didFinishNavigation nav: WKNavigation?) {
    io.printf("done\n")
}
```

---

## Grammar Signal Summary

Every ObjC concept expressed through existing Vertex grammar. No new keywords.

| ObjC concept | Vertex grammar signal |
|---|---|
| Framework binding | `import "darwin/framework/X"` |
| Instance method | binding method with no `self` param |
| Construction + alloc | `func (r: T) init() {}` body present |
| Default init | `Type()` — `alloc` + `init` |
| Named init selector | `Type(initWithX: ...)` — labels matched to binding |
| Nil argument | `nil` to any `T?` param |
| ARC-style release | `auto var` binding |
| Weak reference | `weak let` binding |
| Block parameter | `func(...) -> T` param type on binding method |
| Protocol impl | `class MyClass : Framework.ProtocolName` |
| `dealloc` | `deinit` on darwin-bound class |

---

## File Responsibility Summary

| File | What changes |
|---|---|
| `runtime_objc.go` | `declareObjcRuntime()`, `internSelectorLit()`, `selectorForMethod()`, `resolveInitSelector()` |
| `lower_objc.go` | `emitObjcCall()`, `emitObjcAlloc()`, `emitObjcStartup()`, block struct emit |
| `types.go` | `declareTypes()` populates `isDarwinCls`, `protocolImpls` |
| `decl.go` | `declareRuntime()` calls `declareObjcRuntime()`; `declareFuncs()` detects init bodies into `initCls` |
| `expr.go` | `methodCall()` branches to `emitObjcCall()`; `constructClass()` branches to `emitObjcAlloc()` |
| `stmt.go` | `emitAutoDelete()` branches to `objc_msgSend(sel_release)` for darwin classes |