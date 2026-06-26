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

## Import Path Conventions

The import path prefix is the sole signal for how a binding is lowered.
No annotations or new keywords are needed.

| Import path | What it means | Lowering |
|---|---|---|
| `darwin/framework/X` | ObjC framework (AppKit, UIKit, WebKit, etc.) | ObjC runtime — `objc_msgSend`, selectors, alloc/init |
| `darwin/lib/X` | Plain C library on Darwin (CoreGraphics, libc, etc.) | Direct C extern calls, same as Linux |
| `linux/lib/X` | Plain C library on Linux | Direct C extern calls |

The `darwin/lib/` pattern already works and is stable — for example:

```vertex
import "darwin/lib/c"    // libc on Darwin — direct C calls, no ObjC involvement
import "linux/lib/c"     // libc on Linux  — identical lowering
```

Apple calls many C-based libraries "frameworks" (CoreGraphics, CoreFoundation,
Accelerate), but in Vertex those are imported via `darwin/lib/` not
`darwin/framework/`. The `darwin/framework/` prefix specifically means
ObjC runtime binding — that is the complete and correct distinction.

---

## The Full Pipeline

```
Vertex source
    → Vertex IR (VIR)
        → Machine IR
            → Machine Code / ASM
                → .o
                    → Mach-O binary (macho linker)
                        → signed binary (macho/codesign)
```

---

## How It Fits in the vir Package

The vir package lowers one `ast.Package` into a single `vertex.Module`
via `NewLower`. ObjC support adds no new passes — it hooks into the
four existing phases that `NewLower` already runs in order:

```
NewLower
    declareTypes()      ← detects darwin-bound class decls (externCls map)
    declareExterns()    ← registers ObjC binding methods via resolveImportLib
    declareRuntime()    ← injects objc_getClass / objc_msgSend / sel_registerName
    declareFuncs()      ← normal Vertex functions, unchanged
    declareGlobals()    ← normal globals, unchanged
    lowerBodies()
        frame.methodCall()   ← darwin dispatch path (new branch)
        frame.call()         ← constructor alloc+init injection
```

No new passes. No new IR instructions. Two files added to the package:

```
vir/
    runtime_objc.go     ← declareObjcRuntime(), selector string interning
    lower_objc.go       ← emitObjcCall(), emitObjcAlloc(), block lowering
```

Everything else (types.go, decl.go, expr.go, stmt.go) grows small
targeted branches.

---

## Stage 1 — Vertex Source

The import prefix `darwin/framework/` is the only signal needed.
No new keywords, no annotations.

```vertex
import "darwin/framework/WebKit"

class WKWebView : WebKit {
    func initWithFrame(self: WKWebView, frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView
    func loadHTMLString(self: WKWebView, string: *const char, baseURL: NSURL?)
    func goBack(self: WKWebView)
}

var w = WKWebView()
w.initWithFrame(frame: myRect, configuration: config)
w.loadHTMLString(string: html, baseURL: nil)
w.goBack()
```

---

### Selector Generation — deterministic from the declaration

```
func name + each non-self param label + ":"

func initWithFrame(self, frame, configuration)  →  "initWithFrame:configuration:"
func loadHTMLString(self, string, baseURL)       →  "loadHTMLString:baseURL:"
func goBack(self)                               →  "goBack"
```

This is computed in `runtime_objc.go` by `selectorForMethod(m *ast.MethodSig) string`
and the result is interned as a passive data segment via `internSelectorLit`.

---

### Dispatch Rule — `self` presence

The `self` parameter drives dispatch. No new keywords.

| `self` in params | Dispatch |
|---|---|
| present | instance — `objc_msgSend` on the variable |
| absent  | class — `objc_msgSend` on `objc_getClass` |

In `expr.go`, `frame.methodCall` already checks `f.l.externCls[recvVT.name]`
and takes a no-receiver path. The darwin path extends that branch:

```go
// expr.go — methodCall (existing extern-class branch, extended)
if f.l.externCls[recvVT.name] {
    if f.l.isDarwinCls[recvVT.name] {
        return f.emitObjcCall(recvVT, sel.Sel, x)   // new
    }
    // existing C extern path
    if fi, ok := f.l.methodIdx[key]; ok { ... }
}
```

`isDarwinCls` is a `map[string]bool` populated in `declareTypes` alongside
the existing `externCls` map when the parent resolves to a `darwin:` lib.

---

### Alloc Injection Rule — constructor form only

Handled in `frame.call` in `expr.go`, which already routes `Type()` through
`constructClass`. A darwin check there redirects to `emitObjcAlloc`:

```go
// expr.go — call (existing constructClass branch, extended)
if _, isClass := f.l.classDecls[fn.Name]; isClass {
    if f.l.isDarwinCls[fn.Name] {
        return f.emitObjcAlloc(fn.Name, x)   // new
    }
    return f.constructClass(fn.Name, x)
}
```

| Call site | Compiler action |
|---|---|
| `WKWebView()` | alloc + init |
| `WKWebView(initWithFrame: ...)` | alloc + named init selector |
| `a.URLWithString(...)` | no alloc — dot form, class dispatch only |

---

### Nullable — `?` suffix (§27)

`NSURL?` is already a valid Vertex nullable (§27). No new grammar.
At the VIR level it is `ptr?` — the compiler accepts `nil` / `ptr.null`
at the call site. No ObjC-specific handling needed.

---

### Memory — `auto` and `weak let` (§31.1, §32.1)

`auto` on a darwin-bound class lowers to `objc_msgSend(obj, sel_release)`
rather than `RcRelease`. `weak let` lowers to `objc_storeWeak` /
`objc_loadWeak`. Both are handled in `emitAutoDelete` in `stmt.go`:

```go
// stmt.go — emitAutoDelete (darwin extension)
if f.l.isDarwinCls[vt.name] {
    // emit: objc_msgSend(obj, sel_release)
    f.b.LocalGet(loc)
    f.emitSelCall("release", loc, vt, nil)
    return
}
```

---

### Blocks — anonymous functions (§36)

When a darwin-bound method declares a parameter of function type (§35),
`emitObjcCall` in `lower_objc.go` detects it via the param's `vtype.isRef`
and func type index, then emits a block struct (isa + invoke + descriptor +
captured env) rather than a raw funcref. The anonymous function literal
(§36) is the signal — no new syntax.

---

### Delegates / Protocols — Vertex class as ObjC protocol impl

A Vertex class declared with a darwin protocol parent becomes an ObjC
protocol implementation. `declareTypes` in `types.go` detects this and
records it in a `protocolImpls` map. A new startup function
(`emitObjcStartup` in `lower_objc.go`) is injected before `main` and
calls `objc_allocateClassPair` / `class_addMethod` / `objc_registerClassPair`
for each registered protocol impl.

```vertex
import "darwin/framework/WebKit"

class MyNavDelegate : WebKit.WKNavigationDelegate {
    func webView(self: MyNavDelegate, didFinishNavigation: WKNavigation?)
}

func (d: MyNavDelegate) webView(didFinishNavigation nav: WKNavigation?) {
    io.printf("done\n")
}
```

---

## Stage 2 — What declareObjcRuntime() Injects

`runtime_objc.go` mirrors `runtime_arrays.go` exactly but is even thinner —
no emit logic, pure declarations:

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

    // Weak ref support — only imported when weak let appears on a darwin class.
    reg("objc_storeWeak",
        vertex.FuncType{
            Params: []vertex.Param{{Type: ptr}, {Type: ptr}},
        })
    reg("objc_loadWeak",
        vertex.FuncType{
            Params:  []vertex.Param{{Type: ptr}},
            Results: []vertex.ValType{ptr},
        })

    // Block descriptor global — only imported when block params appear.
    l.mod.Imports.ImportGlobal(
        "darwin:libSystem.dylib", "_NSConcreteStackBlock",
        vertex.GlobalType{Mut: false, Type: ptr})
}
```

`declareRuntime` in `decl.go` calls this under a target check:

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

## Stage 3 — emitObjcCall (lower_objc.go)

This is where the actual VIR emit sequence lives. It is called from
`methodCall` in `expr.go` whenever `isDarwinCls` is true.

```go
// lower_objc.go
func (f *frame) emitObjcCall(recvVT vtype, methodName string, x *ast.CallExpr) vtype {
    cd := f.l.classDecls[recvVT.name]
    m  := f.l.findMethod(cd, methodName)

    sel    := selectorForMethod(m)                      // "loadHTMLString:baseURL:"
    selDat := f.l.internSelectorLit(sel)               // passive data segment

    msgSend := f.l.funcIdx["objc_.objc_msgSend"]
    selReg  := f.l.funcIdx["objc_.sel_registerName"]

    // 1. Register selector — sel_registerName(&"loadHTMLString:baseURL:\0")
    selLoc := f.newLocal(ptrVT)
    f.b.DataAddr(selDat)
    f.b.Call(selReg)
    f.b.LocalSet(selLoc)

    // 2. Receiver
    hasSelf := methodHasSelf(m)
    if hasSelf {
        f.expr(x.Fun.(*ast.SelectorExpr).X, &recvVT)   // push object
    } else {
        // Class dispatch: objc_getClass(&"WKWebView\0")
        clsDat := f.l.internSelectorLit(recvVT.name)
        getClass := f.l.funcIdx["objc_.objc_getClass"]
        f.b.DataAddr(clsDat)
        f.b.Call(getClass)
    }

    // 3. SEL
    f.b.LocalGet(selLoc)

    // 4. Arguments — block params get wrapped; plain params pass through
    sig := f.l.methodSig[recvVT.name+"."+methodName]
    f.pushObjcArgs(x.Args, sig, m)

    // 5. Call
    f.b.Call(msgSend)

    return f.l.objcReturnVType(m)
}
```

Selector strings are interned the same way as string literals — via
`internSelectorLit` in `runtime_objc.go`, which calls `mod.Data.AddPassive`
and deduplicates through a `selectorLits map[string]vertex.DataIdx` on the
`Lower` struct.

---

## Stage 4 — emitObjcAlloc (lower_objc.go)

```go
func (f *frame) emitObjcAlloc(className string, x *ast.CallExpr) vtype {
    clsDat  := f.l.internSelectorLit(className)
    selAlloc := f.l.internSelectorLit("alloc")
    getClass := f.l.funcIdx["objc_.objc_getClass"]
    msgSend  := f.l.funcIdx["objc_.objc_msgSend"]
    selReg   := f.l.funcIdx["objc_.sel_registerName"]

    // objc_getClass("WKWebView")
    f.b.DataAddr(clsDat)
    f.b.Call(getClass)
    clsLoc := f.newLocal(ptrVT)
    f.b.LocalSet(clsLoc)

    // alloc
    f.b.LocalGet(clsLoc)
    f.b.DataAddr(selAlloc)
    f.b.Call(selReg)
    f.b.Call(msgSend)
    objLoc := f.newLocal(ptrVT)
    f.b.LocalSet(objLoc)

    // init selector — "init" or "initWithFrame:configuration:" etc.
    initSel, initMethod := f.l.resolveInitSelector(className, x)
    selDat := f.l.internSelectorLit(initSel)
    f.b.LocalGet(objLoc)
    f.b.DataAddr(selDat)
    f.b.Call(selReg)
    if initMethod != nil {
        sig := f.l.methodSig[className+"."+initMethod.Name]
        f.pushObjcArgs(x.Args, sig, initMethod)
    }
    f.b.Call(msgSend)

    return ptrVT   // darwin objects are raw ptr
}
```

---

## Stage 5 — VIR Output

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

## Stage 6 — Runtime Boot Sequence

```
kernel maps Mach-O into memory
    → dyld reads LC_LOAD_DYLIB entries
    → maps libobjc into process
    → maps WebKit into process
    → ObjC runtime initializers fire
    → Vertex startup fn runs (emitObjcStartup)
        → objc_allocateClassPair / class_addMethod / objc_registerClassPair
          for each protocol impl class
    → WKWebView and all framework classes registered into global class table
    → main() runs
    → objc_getClass("WKWebView") finds it
    → objc_msgSend dispatches through it
```

---

## Stage 7 — Code Signing

```go
exe, err    := l.Link()
signed, err := codesign.SignImage(exe, codesign.Options{Identifier: "myapp"})
os.WriteFile("myapp", signed, 0755)
```

Apple Silicon requires a valid signature — the kernel rejects
unsigned binaries before `main` is reached.

---

## File Responsibility Summary

| File | What changes |
|---|---|
| `runtime_objc.go` | `declareObjcRuntime()`, `internSelectorLit()`, `selectorForMethod()` |
| `lower_objc.go` | `emitObjcCall()`, `emitObjcAlloc()`, `emitObjcStartup()`, block struct emit |
| `types.go` | `declareTypes()` populates `isDarwinCls`, `protocolImpls` alongside existing `externCls` |
| `decl.go` | `declareRuntime()` calls `declareObjcRuntime()` under darwin target guard |
| `expr.go` | `methodCall()` branches to `emitObjcCall()`; `call()` branches to `emitObjcAlloc()` |
| `stmt.go` | `emitAutoDelete()` branches to `objc_msgSend(sel_release)` for darwin classes |

---

## Grammar Signal Summary

Every ObjC concept is expressed entirely through existing Vertex grammar.
No new keywords.

| ObjC concept | Vertex grammar signal | § |
|---|---|---|
| Framework binding | `import "darwin/framework/X"` | §34 |
| Instance method | `self` as first param in binding | §48 |
| Class method / factory | no `self` in binding | §48 |
| Constructor + alloc | `Type()` or `Type(initWith...)` paren form | §31 |
| Nil argument | `nil` to any `T?` param | §27 |
| Nullable return | `-> T?` on binding declaration | §27 |
| ARC-style release | `auto var` binding | §32.1 |
| Weak reference | `weak let` binding | §31.1 |
| Block parameter | `func(...) -> T` param type on darwin-bound method | §35–36 |
| Protocol impl | `class MyClass : Framework.ProtocolName` | §31, §48 |
| Protocol method | associated func (§29) matching selector on protocol class | §29 |
| `dealloc` | `deinit` on darwin-bound class | §31 |