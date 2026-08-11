# objc.md

## Scheme-Qualified Specifier
A module specifier may carry a `scheme:` prefix naming the resolver. `objc:` resolves
through the Objective-C runtime and the framework search path rather than the ordinary
linker path. The scheme is a prefix, matching `node:`, `bun:`, `npm:`, and URI convention
generally.

The text after the scheme is a **framework name**, not a class name:

    "objc:WebKit"  →  WebKit.framework

Framework names are external identifiers fixed by the vendor, so they are written
literally throughout this document rather than as `Sample00N` placeholders. Names
declared *from* a framework are Vertex-side and stay placeholders. Case is significant —
the string is matched against the bundle name.

The specifier remains a string literal, so an unknown scheme is a resolution error, not
a parse error.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
  }
}
```

## Binding
There is no separate import. The `declare module` block is both the declaration and the
binder: names marked `export` inside it enter file scope directly. Go-form `import` binds
Vertex modules by path and has no named-binding form, so a foreign surface has nowhere
else to come from — and since the compiler reads no headers, the block is already the
sole source of truth. Importing what you just declared, in the file you declared it in,
would be pure duplication.

A declaration needed in more than one file goes in a Vertex module that holds the block,
and is reached the ordinary way:

```vertex
import "app/platform/webkit"
```

## Linkage
A `declare module "objc:…"` block is what triggers the link. The scheme selects the
framework flavor of the lookup (`-framework WebKit`) over the library flavor used by the
C-facing form in `extern.md` (`-lfoo`). Same production, same job, different resolver.

A framework with no `declare module` block is not linked. Direct precedent: Clang module
maps spell this as `link framework "WebKit"`.

Weak linking, framework search paths, and deployment target are build configuration, not
language. This follows Apple, where `-weak_framework` is a linker flag that Swift never
gave syntax to.

## Foreign Module Declaration
One block per framework, declaring the subset of its surface the program uses.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    constructor()
    sample002(a: Sample003): void
  }
}
```

## Declaration Fidelity
The compiler does not read framework headers. Everything inside the block is taken on
trust and lowered directly into selector sends and ABI calls — a signature that disagrees
with the real framework produces a miscompile at the boundary, not a diagnostic. Same
trust model as a C header declaration in `extern.md`, with a wider blast radius: a wrong
C signature usually corrupts a stack frame, a wrong selector usually fails at dispatch.

Three things must match exactly:

- **Selector spelling**, including trailing colons and piece count.
- **Argument types**, at C ABI granularity — `int32` and `int64` are not interchangeable.
- **Nullability**, since Vertex bindings are non-nullable unless a union says otherwise.

## Foreign Ambient Class Declaration
Declares a class whose definition, layout, and dispatch all live in the foreign runtime.
Legal only inside a `declare module "objc:…"` block.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    constructor()
  }
}
```

## Foreign Class Hierarchy
Foreign ambient classes may declare `extends`. This is not an exception to "classes have
no inheritance" — the hierarchy already exists in the foreign runtime, and the clause
describes it rather than creating it. Same latitude `declare struct` gets for layout.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 { }
  export declare class Sample002 extends Sample001 { }
}
```

Inherited members are visible on the subclass. Vertex-side classes still cannot extend
anything, foreign or not.

## Static Method Declaration
Class methods (`+`) declare as `static`; instance methods (`-`) declare bare. Factory
methods stay static rather than becoming constructors — Vertex has one initializer per
type and does not synthesize alternates.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    static sample002(): Sample001
    sample003(): void
  }
}
```

## Protocols
An Objective-C protocol is an `interface`. Conformance is `implements`, which
`types.md` already establishes as the sole route to polymorphism.

```vertex
declare module "objc:WebKit" {
  export interface Sample001 {
    sample002(a: Sample003): void
  }
}
```

## Properties
`@property` maps to a field. `readonly`, already in `types.md`, expresses a readonly
property. The getter/setter send is implicit in the member expression — there is no
accessor call syntax.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    readonly sample002: int32
    sample003: Sample004 | null
  }
}
```

## Nullability
Objective-C object pointers are nullable by default; Vertex bindings are not. An ambient
declaration must therefore spell absence explicitly. An audited framework's `_Nonnull`
maps to the bare type; everything else takes the union.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    static sample002(a: Sample003): Sample001 | null
  }
}
```

## Nullable Access
`if let` is the ordinary route to a nullable foreign result, and unwraps and binds in one
step.

```vertex
if let a = Sample001.sample002(b) {
  a.sample003()
}
```

Optional chaining remains available where the result is discarded rather than used.

```vertex
a?.b
```

## Labeled Call
First selector piece positional, remaining pieces as a trailing object literal. This is
the ordinary spelling; the two below are escape hatches.

```vertex
a.sample001(b, { sample002: c })
```

## String-Literal Method Declaration
Declares a method whose name is the full selector string. Required when several selectors
share a first piece and would collide under the labeled form — the common case for
delegate protocols, where most methods begin with the same piece.

```vertex
class Sample001 {
  "sample002:sample003:"(a: int32, b: int32): void {
  }
}
```

## Literal Selector Call
Exact selector string as method name. Last resort — selectors that do not decompose into
legal identifiers, or that collide even after the declaration above.

```vertex
a["sample001:sample002:"](b, c)
```

## Blocks
An Objective-C block is an ordinary function type.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    sample002(a: string, b: (c: Sample003 | null, d: Sample004 | null) => void): void
  }
}
```

Syntax is settled; capture and lifetime are not — see *Open Questions*.

## Error Out-Parameters
Objective-C signals failure through a trailing `NSError **` combined with a sentinel
return. Vertex spells the result as a return union rather than inferring a fallible form
from the parameter shape.

```vertex
declare module "objc:WebKit" {
  export declare class Sample001 {
    sample002(a: Sample003): Sample004 | null
  }
}
```

Swift infers `throws` here, but only because it reads a header it did not write, and the
inference required a documented pile of special cases: which parameter position counts,
which return types signal failure, and when to strip a trailing "AndReturnError" from the
base name. Vertex is told, so it infers nothing.

## Enums
`NS_ENUM` maps to the enum-with-underlying-type form. Case names are written as they
appear — no prefix stripping, since nothing is being inferred.

```vertex
enum Sample001: int64 {
  Sample001A = 0
  Sample001B = 1
}
```

## Naming
No heuristic renaming, in either direction. The name in the declaration is the name in the
program; the selector is either derived from it by the labeled-call rule or written
literally. Swift's importer carries a word-boundary algorithm, enum prefix stripping, and
an "omit needless words" pass — all of it a consequence of reading headers it cannot edit.
Vertex has no such layer because it has no such input.

## Availability
Availability is not spelled in Vertex source. A framework's symbols carry OS version
ranges the compiler cannot see, and encoding them inline would burden every declaration.

Where availability data is needed it lives in a sidecar keyed by framework name — the same
shape as Clang's `.apinotes`, which exists for exactly this problem: annotating an API you
do not own without editing it.

## Object Lifetime
Foreign objects are refcounted by the foreign runtime, not by Vertex's inline header.
Bindings to them behave as `shared_ptr<T>` — retain on copy, release at last reference.
`unique_ptr<T>` is not available for foreign objects: the runtime hands out shared
references and cannot promise uniqueness.

```vertex
let a: shared_ptr<Sample001> = Sample001()
```

Note this is the Managed-tier construction form from `pointers.md`, not `make_shared` —
the allocation is the foreign runtime's, so there is nothing for Vertex to allocate in
place.

## Weak Foreign Reference
Delegate-style back-references are the standard retain cycle. Spell them weak.

```vertex
let a: weak_ptr<Sample001> | null
```

## Foreign Class Decorator
Marks a Vertex class as dispatchable into from the foreign runtime. This changes
allocation, not just visibility: the object gets a foreign runtime header instead of
Vertex's inline refcount header, and its lifetime is managed by that runtime.

```vertex
@objc class Sample001 implements Sample002 {
}
```

Consequences:

- **Refcount is foreign.** `destructor` runs when the foreign runtime releases the last
  reference, not Vertex's counter.
- **Methods are dispatched dynamically.** Members reachable from the foreign runtime
  cannot be statically devirtualized.
- **`implements` names a protocol.** Conformance is registered with the runtime so
  `conformsToProtocol:` answers correctly.

## Value Types at the Boundary
C structs used by frameworks (rect, point, size, and similar) are ordinary `struct`
declarations and do not go through the `objc:` scheme. Only classes and protocols do.

```vertex
struct Sample001 {
  x: float64
  y: float64
}
```

## Grammar Cost
Zero. Scheme specifiers are string literals; `declare module`, `export declare class`,
ambient `extends`, `interface`, and class decorators are all existing productions;
`a["sel:"](b)` is a computed member call; blocks are function types; error conventions are
return unions. Nothing in this document belongs in `grammar_diff_v2.md`.

The one thing this document *removes* is the ES named import — see *Binding*. That is a
subtraction from the base grammar, already made in `grammar_notes.md` by the move to
Go-form imports, and not a cost this document incurs.

Weak linking and availability were the two candidates that would have needed decorators on
ambient declarations. Both were moved out of the language — matching Apple, which keeps
the first in the linker and the second in a sidecar.

## Open Questions
- **Block capture and lifetime.** An escaping block must retain its captures, which
  interacts with `mutating` being non-escaping (`types.md`).
- **Selectors as values.** No equivalent of `@selector(…)`; only literal-string sends.
- **Categories.** No route to adding methods to a foreign class.
- **Autorelease pools.** No scope construct; unclear whether one is needed given
  deterministic release. Methods returning autoreleased objects may need a defined
  hand-off point.
- **`instancetype` in an inherited factory.** A static method returning the containing
  type is declared literally; whether a subclass redeclares it is unresolved.
- **Cross-file foreign declarations.** *Binding* routes these through a Vertex module
  holding the block. Whether re-exporting a foreign name through an ordinary module is
  legal, and whether two files may declare the same framework, is unspecified.

---

## Worked Example: WebKit

A window-less `WKWebView` that loads a page, receives navigation callbacks, and evaluates
a script on completion. Two frameworks, so two blocks — Foundation supplies the URL types,
WebKit the view.

```vertex
namespace pageloader

declare module "objc:Foundation" {
  export declare class NSError {
    readonly code: int64
    readonly domain: string
  }

  export declare class NSURL {
    static URLWithString(a: string): NSURL | null
    readonly absoluteString: string | null
  }

  export declare class NSURLRequest {
    static requestWithURL(a: NSURL): NSURLRequest
    readonly URL: NSURL | null
  }
}

declare module "objc:WebKit" {
  export declare class WKWebViewConfiguration {
    constructor()
  }

  export declare class WKNavigation {
  }

  export interface WKNavigationDelegate {
    "webView:didFinishNavigation:"(a: WKWebView, b: WKNavigation | null): void
    "webView:didFailNavigation:withError:"(
      a: WKWebView,
      b: WKNavigation | null,
      c: NSError
    ): void
  }

  export declare class WKWebView {
    constructor(a: CGRect, b: WKWebViewConfiguration)

    navigationDelegate: weak_ptr<WKNavigationDelegate> | null
    readonly URL: NSURL | null
    readonly estimatedProgress: float64

    loadRequest(a: NSURLRequest): WKNavigation | null
    evaluateJavaScript(
      a: string,
      b: { completionHandler: (c: void_ptr | null, d: NSError | null) => void }
    ): void
  }
}

struct CGPoint {
  x: float64
  y: float64
}

struct CGSize {
  width: float64
  height: float64
}

struct CGRect {
  origin: CGPoint
  size: CGSize
}

@objc class PageLoader implements WKNavigationDelegate {
  private view: shared_ptr<WKWebView>
  private done: bool

  constructor(frame: CGRect) {
    this.view = WKWebView(frame, WKWebViewConfiguration())
    this.view.navigationDelegate = weak_ptr(this)
    this.done = false
  }

  load(spelling: string): bool {
    if let url = NSURL.URLWithString(spelling) {
      this.view.loadRequest(NSURLRequest.requestWithURL(url))
      return true
    } else {
      return false
    }
  }

  "webView:didFinishNavigation:"(a: WKWebView, b: WKNavigation | null): void {
    this.done = true
    a.evaluateJavaScript("document.title", {
      completionHandler: (result: void_ptr | null, error: NSError | null): void => {
        if error !== null {
          return
        }
      }
    })
  }

  "webView:didFailNavigation:withError:"(
    a: WKWebView,
    b: WKNavigation | null,
    c: NSError
  ): void {
    this.done = true
  }

  destructor() {
  }
}
```

What the example exercises:

- **Two frameworks, two link edges.** Each `declare module` emits its own framework link,
  and each binds its own exported names into the file.
- **String-literal declarations, non-optionally.** Every `WKNavigationDelegate` method
  begins with `webView:`, so the labeled form would collide on all of them. This is the
  motivating case for the escape hatch, not a corner case.
- **Nullability at every foreign return.** `URLWithString:` genuinely returns nil on a
  malformed string, and `if let` forces the check before `requestWithURL:` while binding
  the unwrapped value in one step.
- **A weak delegate.** `PageLoader` holds the view; the view holds the loader weakly.
  Without `weak_ptr` the pair never deallocates.
- **A block as a function type.** `completionHandler:` is the second selector piece, so it
  lands in the trailing object literal, and its value is an ordinary arrow function.
- **`destructor` on a foreign-refcounted object.** `PageLoader` carries a foreign header
  because of `@objc`, so teardown runs when the runtime releases it, not Vertex.