# js.md

## Why `js` and Not `bundle`

The earlier name pointed at the wrong thing. Bundling is a resolution story — which
specifier finds which file — and resolution belongs to the platform line's second job, not
its first. What actually fixes the type table here is the ECMA-262 value model: one numeric
representation, host-owned memory, no layout anywhere.

`js` names that. It also spans every engine that implements it — browser, Node, Deno,
workers, Hermes, QuickJS — where `bundle` excluded the unbundled ones and `browser`
excluded most of them.

Go reached the same conclusion for the same reason, putting `js` in its OS slot rather than
its architecture slot, on the grounds that a JS engine is what sits where an OS normally
would.

```vertex
use host
use js
```

Or, since `js` implies `host`:

```vertex
use js
```

---

## What This Target Is

Host-owned memory, no pointer family, no manual allocation, no layout control, no
`destructor`, `int` as the only numeric type. What it adds over `any` isn't a type — it's
*reach*: the ability to `declare module` a foreign JS surface.

This is a target assertion, not a selector. The whole build targets one platform, and
`use js` errors if the build's actual target disagrees. It never selects the target itself.

It takes no runtime or accelerated-backend line. A JS engine abstracts the OS away entirely
and has no accelerated route; either line here is an error, not a no-op.

**Not a runtime name.** `js` doesn't say browser, Node, Deno, or worker — those present the
same value model and the same `declare module` mechanism, and which one you're on is build
configuration. A file that needs `document` and a file that needs `node:fs` are both
`use js`; the difference is which specifier they name, and the build is what makes one of
them resolve.

---

## Specifier and Resolution

Exactly one resolver: whatever the host tooling does with the specifier — a bundler
(webpack, esbuild, Vite), Node's own resolution, Deno's. No scheme prefix exists, because
there's nothing to disambiguate.

```vertex
declare module "websocket" {
  export declare class Sample001 {
    constructor(a: string)
    send(a: string): void
  }
}
```

The specifier string is whatever the host expects — a bare package name, a relative path, a
built-in module name, a URL under Deno. Vertex doesn't interpret it; it's handed over
unchanged.

Resolution happens at bundle or build time, per the host tool's own rules. A missing module
is the host's error, in the host's format — Vertex has nothing to add.

## Binding and Linkage

`declare module` is both declaration and binder — `export`ed names enter file scope
directly, with no separate import. A declaration needed in more than one file goes in a
Vertex module that holds the block:

```vertex
import "app/platform/browser"
```

No link step, no classpath. A present module with a mismatched shape fails at first use,
not at build time — the compiler doesn't read the module's source, only the declaration.

---

## Object Model

Every reference is GC-owned by the host engine. Bindings are ordinary object references —
no pointer syntax, nothing to spell at the call site.

```vertex
var a = Sample001("wss://example.invalid")
a.send("ping")
```

**No `weak_ptr` here**, unlike `android`. JS has `WeakRef` and `FinalizationRegistry`, but
nothing in the language surface currently binds to them.

The asymmetry is deliberate rather than an oversight. `weak_ptr` survives on `android`
because the framework hands you long-lived roots you didn't create — a static listener
registry, a `Service` outliving the `Activity` that bound it — and the collector is correct
to hold everything they reach. The JS event loop has fewer such roots, and the ones it has
(a `setInterval` closure, an unremoved listener) are usually fixed by unregistering rather
than by weakening. Tracked as open below; a real leak-shaped case would reopen it.

Nothing else from the pointer family exists. No raw pointer, no manual allocation, no
layout control, no `sizeof`.

## `destructor`

invaild. Teardown in Vertex is deterministic and scope-bound; `FinalizationRegistry`
callbacks run at an unspecified time relative to collection, and the spec doesn't promise
they run at all.

Cleanup for foreign resources — an open socket, a `MediaStream` track, an
`AbortController`, a subscription — is written by hand on every exit path.

## Numerics

**`int` only.** Every sized type — `int8`…`uint64`, `usize`, `float32`/`float64` — is
invaild.

A JS engine has exactly one numeric representation, IEEE-754 double, for anything not
explicitly boxed as `BigInt`. An unsized type is therefore always correct, and a sized one
would assert a width the runtime doesn't distinguish — `int32` would be a claim the engine
has no way to honor or violate.

```vertex
int
string
bool
```

`bool` is `boolean`.

This is the mirror image of `android`, which mandates sized types for the same underlying
reason: the target's own representation is what decides, and here there's only one.

`BigInt` has no binding yet — see open questions.

---

## Foreign Declarations

```vertex
declare module "websocket" {
  export declare class Sample001 {
    constructor(a: string)
    send(a: string): void
    readonly readyState: int
  }
}
```

Taken entirely on trust and lowered directly to property access and calls. JS carries no
compile-time signature, so there's nothing to verify beyond what Vertex itself declares. A
call that disagrees with the real object's shape fails at the call site with whatever the
engine raises — a `TypeError` or similar, not a Vertex-level diagnostic.

That's a weaker guarantee than the other targets offer, and worth being explicit about: on
`linux` a wrong signature fails at link time, on `android` it panics with a named
`NoSuchMethodError`. Here it surfaces as an ordinary runtime error in the host's own terms,
indistinguishable from a bug in the foreign library.

### Hierarchy

A foreign ambient class may declare `extends`, describing a prototype chain that already
exists at runtime rather than creating one.

```vertex
declare module "dom" {
  export declare class Sample001 { }
  export declare class Sample002 extends Sample001 { }
}
```

### Overloads

JS has no overload resolution — one name, one implementation, arity and types checked only
at the call boundary by the runtime. There is exactly one declared signature per name.

Where a real API accepts several shapes, the declaration picks one, or spells the union in
the parameter type.

### Exceptions

JS unwinds; Vertex doesn't. A throwing foreign method is a return union at the boundary,
told rather than inferred:

```vertex
declare module "fs" {
  export declare class Sample001 {
    readFileSync(a: string): span<byte> | Sample002
  }
}
```

A thrown value not captured by the union panics rather than silently dropping.

### Nullability

JS distinguishes `null` and `undefined`; Vertex bindings collapse both into the same
non-nullable-by-default rule. A value that may be absent is spelled as an explicit union,
and `if let` is the ordinary unwrap:

```vertex
declare module "dom" {
  export declare class Sample001 {
    querySelector(a: string): Sample002 | null
  }
}
```

```vertex
if let a = Sample001.querySelector(b) {
  a.doSomething()
}
```

The collapse is a real narrowing: a foreign API that means something different by `null`
than by `undefined` can't express it here. No case has yet needed the distinction.

### Generics

JS has no type parameters at runtime — not erasure, just the absence of any type
information to erase. A foreign generic-shaped API (a `Map<K, V>`-style class) declares
with Vertex type parameters purely for the call site's own benefit. Nothing crosses the
boundary to check, so there's no checked cast on return — the value is trusted at the
declared type with no verification step at all.

This differs from `android`, where erasure at least leaves a cast to take.

---

## Worked Example

```vertex
namespace pageloader

use host
use js

declare module "dom" {
  export declare class Element {
    textContent: string | null
  }
  export declare class Document {
    querySelector(a: string): Element | null
  }
}

declare module "fetch" {
  export declare class Response {
    readonly ok: bool
    readonly status: int
    text(): string
  }
  export func fetch(a: string): Response
}

declare module "global" {
  export const document: Document
}

func loadInto(url: string, selector: string): void {
  if let target = document.querySelector(selector) {
    let response = fetch(url)
    if response.ok {
      target.textContent = response.text()
    } else {
      target.textContent = "failed to load"
    }
  }
}
```

This exercises a bare specifier with no scheme, an ambient `const` binding for a global
singleton, `if let` narrowing a nullable DOM query, and a foreign call whose success is
checked by an ordinary field rather than a return union.

The example sidesteps `fetch`'s real signature — it returns a `Promise`, and rejection
isn't modeled here. Working through `.ok` is deliberate, and the gap it papers over is the
first open question below.