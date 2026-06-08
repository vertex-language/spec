# Vertex UI XML — Compiler Flow

## How VSX and the Platform UI Packages Connect

This document describes the exact path a VSX block travels through the
compiler when the platform UI packages (`ui_linux.vs`, `ui_darwin.vs`,
`ui_windows.vs`) are already written and imported.

---

## The Setup

A Vertex UI source file looks like this:

```swift
package app
build linux

import "github.com/vertex-language/ui"
import bundle "github.com/vertex-language/user/your-browser-bundle"

func render() -> Element {
    return (
        <>
            <Column>
                <WebView src={bundle} ></WebView>
                <Text>{state.status}</Text>
                <Button label={"Send"} onClick={func() { send() }} />
            </Column>
        </>
    )
}
```

The platform UI packages are pure Vertex + Native Interface:

```
github.com/vertex-language/ui/
├── ui_linux.vs       ← build linux   — wraps GTK via lib/gtk
├── ui_darwin.vs      ← build darwin  — wraps AppKit via darwin/appkit
└── ui_windows.vs     ← build windows — wraps WinForms via lib/winforms
```

Each file follows the same pattern — for example `ui_linux.vs`:

```swift
package ui
build linux

import "lib/gtk"

class Gtk : gtk {
    func gtk_box_new(orientation: int, spacing: int) -> any opaque
    func gtk_label_new(text: any char) -> any opaque
    func gtk_button_new_with_label(label: any char) -> any opaque
    func gtk_container_add(container: mut any opaque, widget: any opaque)
}

struct Column {
    var handle: any opaque
}

struct Text {
    var handle: any opaque
}

struct Button {
    var handle: any opaque
    var label: string
}

func init(c: mut Column) {
    var g = Gtk()
    c.handle = g.gtk_box_new(1, 0)
}

func init(b: mut Button, label: string) {
    var g = Gtk()
    b.handle = g.gtk_button_new_with_label(label.any())
    b.label  = label
}

func addChild(c: mut Column, child: any opaque) {
    var g = Gtk()
    g.gtk_container_add(c.handle, child)
}
```

---

## Compilation Pipeline — Step by Step

### Step 1 — `CompileFiles` builds the package

In `compiler.go`, `CompileFiles` calls `ParseFile` on every `.vs` source
file. Each `SourceFile` records its `BuildTags`, its `Imports`, and its
parse tree.

```go
// compiler.go
sf, err := ParseFile(p)
pkg.Files = append(pkg.Files, sf)
```

---

### Step 2 — `loadImports` resolves the ui package

`loadImports` walks every import in every file. When it reaches:

```swift
import "github.com/vertex-language/ui"
```

`ParseImportPath` classifies it as `ImportModule` (not a native prefix).
`Resolver.ResolveFiles` locates the directory and calls `vertexFiles` to
collect all `.vs` files in it:

```
ui_linux.vs
ui_darwin.vs
ui_windows.vs
```

`PlatformMatch` (in `package.go`) then filters the list against the active
`BuildTags`. On a `build linux` compilation only `ui_linux.vs` passes:

```go
// package.go
func PlatformMatch(filename string, tags *BuildTags) bool {
    base := strings.TrimSuffix(filepath.Base(filename), ".vs")
    for _, p := range []string{"linux", "darwin", "windows"} {
        if strings.HasSuffix(base, "_"+p) {
            return tags.Has(p)
        }
    }
    return true
}
```

The parsed files from `ui_linux.vs` are appended into `pkg.Files` alongside
the application files. From this point the compiler sees one flat package.

---

### Step 3 — Pass 1: `checker.Run()` collects all declarations

`checker.Run()` (in `checker.go`) walks every top-level declaration across
all files now in `pkg.Files`. For `ui_linux.vs` it processes:

**`class Gtk : gtk`** → `collectNativeClass`

```go
// checker.go
ct := &ClassType{Name: "Gtk", Native: true, Parent: "gtk"}
c.scope.Define(&Symbol{Name: "Gtk", Kind: SymType, Type: ct})
// Each method also registered:
c.scope.Define(&Symbol{Name: "gtk_box_new",          Kind: SymNative, Type: ft})
c.scope.Define(&Symbol{Name: "Gtk.gtk_box_new",      Kind: SymNative, Type: ft})
c.scope.Define(&Symbol{Name: "gtk_container_add",    Kind: SymNative, Type: ft})
// ...
```

**`struct Column`**, **`struct Text`**, **`struct Button`** → `collectStruct`

```go
st := &StructType{Name: "Column", Fields: [...]}
st.Size = LayoutStruct(st.Fields)
c.scope.Define(&Symbol{Name: "Column", Kind: SymType, Type: st})
// same for Text, Button
```

**`func init(c: mut Column)`**, **`func addChild(...)`**, etc. → `collectFuncDecl`

Because the first parameter's type is `Column` (a known `StructType`),
`receiverTypeName` fires and the function is registered twice:

```go
// checker.go — collectFuncDecl
c.scope.Define(&Symbol{Name: "init",           Kind: SymFunc, Type: ft})
c.scope.Define(&Symbol{Name: "Column.init",    Kind: SymFunc, Type: ft})
c.scope.Define(&Symbol{Name: "Column.addChild",Kind: SymFunc, Type: ft})
```

After Pass 1 the global scope contains:
`Column`, `Text`, `Button`, `Gtk`, and every associated function — all
as ordinary Vertex symbols.

---

### Step 4 — The VSX block is captured

The base Vertex parser reaches the `return (` expression. The next token
is `<>`, which triggers span-capture mode. The parser tracks tag depth
and collects every token up to the matching `</>`, producing a
`RawVsxSpan`. The `RawVsxSpan` sits in the main AST as a placeholder.

---

### Step 5 — VSX parser produces the node tree

The base parser calls into the VSX parser:

```go
vsxTree, err := vsxparser.Parse(span)
```

The VSX parser has no knowledge of Vertex types. It produces:

```
VsxFragment
  VsxElement{tag: "Column"}
    VsxElement{tag: "Text"}
      VsxExprSlot{src: "state.status"}
    VsxElement{tag: "Button"}
      VsxAttr{name: "label",   value: VsxExprSlot{src: `"Send"`}}
      VsxAttr{name: "onClick", value: VsxExprSlot{src: "func() { send() }"}}
```

Expression slots inside `{}` are captured as raw source strings. The VSX
parser does not parse their contents.

---

### Step 6 — Base parser resolves the node tree against scope

The base parser walks the `VsxNode` tree and performs integration. This
is where the platform package does its work.

#### Tag resolution

Each `VsxElement.tag` is looked up in the scope built in Step 3:

```
"Column" → scope.Lookup("Column") → Symbol{Kind: SymType, Type: *StructType}
"Text"   → scope.Lookup("Text")   → Symbol{Kind: SymType, Type: *StructType}
"Button" → scope.Lookup("Button") → Symbol{Kind: SymType, Type: *StructType}
```

Because these are `StructType`s (not native), they have real field layouts
and associated functions registered under `"Column.init"`, `"Button.init"`,
etc. An unknown tag at this stage is a compile error — the VSX parser
never sees it.

#### Attribute resolution

`label={"Send"}` on `<Button>` → matched against `Button`'s field list.
`Button.label` is `string` — the expression `"Send"` type-checks as
`string`. A type mismatch here is a normal Vertex type error.

`onClick={func() { send() }}` → matched against `Button`'s field or
parameter list for a `func()` type. The anonymous function is a valid
Vertex `AnonFunc` expression.

#### Expression slot resolution

Each `VsxExprSlot.src` is fed back into the base Vertex expression parser:

```
"state.status"        → FieldAccess{recv: state, field: status}
`"Send"`              → StringLit{"Send"}
"func() { send() }"  → AnonFunc{body: CallExpr{send}}
```

Source positions are reconstructed from the original span offset so error
messages point to the correct line and column inside the VSX block.

#### Node replacement

The `RawVsxSpan` placeholder is replaced by a resolved `VsxTree` containing
the fully integrated subtree. Every node is now an ordinary Vertex AST node:

```
CallExpr{Column.init}
  CallExpr{Text.init}
    FieldAccess{state, status}
  CallExpr{Button.init, label: StringLit{"Send"}}
    AnonFunc{CallExpr{send}}
```

From this point the compilation pipeline — `Generate`, `CodeGen` — sees
only these ordinary nodes. It does not know or care that they came from
VSX syntax.

---

### Step 7 — Pass 2a: native class imports registered

In `codegen_decl.go`, `collectNativeClass` processes `class Gtk : gtk`.
It calls `CollectNativeFuncs` which builds `BuildImportName` decorated
names (e.g. `gtk_box_new@i32.i32:ptr`) and registers each method as a
wasm import:

```go
cg.mod.Imports.AddFunc("lib/gtk", "gtk_box_new@i32.i32:ptr", typeIdx)
```

The wasm function index is patched back into the scope symbol so that
later call sites can emit `call $idx` directly.

---

### Step 8 — Pass 2b: Vertex function slots registered

`collectFuncSlot` registers `Column.init`, `Button.init`, `addChild`,
`render`, etc. as local wasm functions. The `main` and qualifier-bearing
functions get export entries. All others are internal.

---

### Step 9 — Pass 2c: function bodies emitted

`genFuncBody` drives `funcGen` for each registered function. When it
reaches the resolved VSX tree — now plain `CallExpr` nodes — code
generation proceeds exactly as it would for any hand-written Vertex call:

**`CallExpr{Column.init}`**
→ `genCall` → `scope.Lookup("Column.init")` → `SymFunc` → `body.Call(idx)`

**`CallExpr{Gtk.gtk_box_new}`** (called inside `Column.init`)
→ `genMethodCall` → `scope.Lookup("Gtk.gtk_box_new")` → `SymNative`
→ receiver is a namespace placeholder, dropped
→ args pushed, `body.Call(importIdx)`
→ wasm import slot for `lib/gtk` :: `gtk_box_new@i32.i32:ptr`

**`FieldAccess{state, status}`** (inside `<Text>`)
→ `genFieldLoad` → byte-offset load from the frame slot of `state`

**`AnonFunc{...}`** (onClick handler)
→ `genPrimary` → function pointer / index pushed as `i32.const`

---

## What the Final Wasm Module Contains

| Section   | Contents |
|-----------|----------|
| **Imports** | `lib/gtk` :: `gtk_box_new@i32.i32:ptr`, `gtk_label_new@ptr:ptr`, `gtk_button_new_with_label@ptr:ptr`, `gtk_container_add@ptr.ptr` |
| **Functions** | `Column.init`, `Text.init`, `Button.init`, `addChild`, `render`, `main` |
| **Data** | Interned strings: `"Send"`, etc. at offset `0x0100` |
| **Memory** | 2 pages (128 KiB). Frame base at `0x4000` for struct locals |
| **Exports** | `main` |

The VSX syntax, the `VsxNode` tree, and the `RawVsxSpan` placeholder
are all gone. The module is indistinguishable from one hand-written
without any XML syntax at all.

---

## The Invariant

VSX does not know what platform it is on.
The platform packages do not know they will be called from VSX.
The compiler does not know or care that the `CallExpr` nodes it is
emitting originated from angle-bracket syntax.

The seam is the scope. Everything else follows from that.