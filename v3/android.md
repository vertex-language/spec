# android.md

## Why There Is No `jvm` Target

Vertex doesn't need one. Walk the cases a general `jvm` profile would serve:

- **Portable business logic** — already `any`. It compiles under every target, including
  an Android build, without asserting anything.
- **Desktop and server work** — already `native`, with real machine access, the full
  pointer family, and C interop. Nothing about running a JVM makes that code better.
- **Android** — the one case where you don't get to pick. The runtime owns memory, the API
  surface is only reachable by class and descriptor, and no amount of `native` gets you an
  `Activity`.

So the JVM isn't a target Vertex chooses; it's machinery underneath the one target that
has no alternative. `use host` + `use android` covers it, and a separate `jvm` name would
be a second spelling for a profile with one real consumer.

This is a scope decision, not a claim about the JVM. Descriptors, binary names, and
classpath resolution are all still exactly what this document describes — they're just
reached by naming Android, because that's who's asking.

```vertex
use host
use android
```

Or, since `android` implies `host`:

```vertex
use android
```

Server-JVM and Kotlin packages remain reachable — `java.util` is a package name like any
other, and a library that happens to run on both loses nothing. What's gone is the ability
to *assert* a bare JVM target, which nothing in Vertex was using.

---

## What This Target Is

Host-owned memory, no pointer family, no manual allocation, no layout control, no
`destructor`. Sized numerics only. What it unlocks is a foreign namespace — packages,
binary names, and descriptors that must match exactly, since two packages can each define
a class of the same name.

This is a target assertion, not a selector. The whole build targets one platform, and
`use android` errors if the build's actual target disagrees. It never selects the target
itself.

It takes no runtime or accelerated-backend line. ART abstracts the OS away, and there's no
accelerated route; either line here is an error, not a no-op.

---

## Specifier and Resolution

The specifier is a package name, written literally, case-sensitive, vendor-fixed.

```vertex
declare module "android.widget" {
  export declare class Sample001 {
  }
}
```

There is exactly one resolver — the classpath — so no scheme prefix exists and none is
needed.

`android.widget`, `android.app`, `java.util`, and any Kotlin or third-party package are all
the same mechanism. There is no special Android namespace and no special handling for one.

**Classpath composition is build configuration.** Which `android.jar`, which API level,
which minSdk, whether a desktop JDK is on the path instead — none of that is spelled in
source. The platform line never carries a version, and the grammar couldn't express one:
`UseDirective: use Identifier` takes no arguments.

That's deliberate. API level is the fact you'd most want the line to carry, and it's a
number that changes on someone else's schedule. Encoding it would make every source file a
place that needs editing when minSdk moves.

## Binding and Linkage

`declare module` is both declaration and binder — `export`ed names enter file scope
directly, with no separate import. A declaration needed in more than one file goes in a
Vertex module that holds the block:

```vertex
import "app/platform/android"
```

No link step. Classes resolve by name from the classpath at first use. A missing class or
member panics (`NoClassDefFoundError` / `NoSuchMethodError`) — the failure surfaces when
the code runs, not when the build finishes.

---

## Object Model

Every reference is GC-owned by the host runtime. Bindings are ordinary object references —
no pointer syntax, nothing to spell at the call site.

```vertex
var a = Sample001()
a.sample002(0)
```

The one exception is **weak references**. A live root outliving the object it points to —
a long-lived callback, a static holder, a background thread capturing `this` — isn't a
cycle a tracing collector handles. It's a real root, and the collector is correct to keep
the object alive. `weak_ptr<T>` / `.lock()` covers it:

```vertex
var strong: Sample001 = Sample001()
var weak: weak_ptr<Sample001> = weak_ptr(strong)

if let live = weak.lock() {
  live.doSomething()
}
```

This is the practical Android leak: an `Activity` captured by something that outlives it.
It survives into a target with no pointer family precisely because the shape of the problem
isn't about ownership — it's about visibility.

Nothing else from the pointer family exists. No raw pointer, no manual allocation, no
layout control, no `bit_cast`, no `sizeof`.

## `destructor`

invaild. Teardown in Vertex is deterministic and scope-bound; ART's finalizers and
`Cleaner` run on an unspecified thread at an unspecified time relative to collection. The
two can't be reconciled by declaring one in terms of the other.

Cleanup for foreign resources — cursors, streams, wake locks, bound services — is written
by hand on every exit path.

## Value Types

No value types pre-Valhalla, so `struct` lowers to a class, which risks the
structural-copy guarantee silently becoming aliasing. Unresolved between defensive copy,
scalarize-with-fallback, and requiring Valhalla.

`readonly` is a safe no-op either way. `mutating` is provisionally an error until a route
is picked.

## Numerics

**Sized types are mandatory.** Descriptors are exact and demand a stated width, so any
numeric field or parameter crossing the boundary must be sized.

```vertex
int8
int16
int32
int64
uint8
uint16
uint32
uint64
usize
float32
float64
bool
```

No unsigned types on the other side — `uint8`…`uint64` lower to same-width signed
primitives with reinterpreted operations. `usize` is `long`. `bool` is `boolean`.

Whether `int` is invaild everywhere or only where a descriptor is emitted is open — see
platforms.md. Java's `int` is already exactly 32 bits, so the narrow reading costs nothing
at the ABI; the question is whether the wider rule is worth keeping for its simplicity.

---

## Class Lowering — Inferred, Not Decorated

Every `class` in a `use android` file is a real class file: stable binary name, public
members, dispatchable from the host runtime. There is no decorator to write.

```vertex
use android

class MainActivity extends Activity {
}
```

The reason is that there was never a second option. On ART a class is a class file — that's
the only lowering available — so a decorator marking one as "dispatchable from the host
runtime" would be marking the default. `use android` already says everything `@jvm` used to
say, one line earlier and once per file instead of once per class.

This also removes a whole error class. A framework-instantiated `Activity` missing its
decorator fails at runtime with a `ClassNotFoundException` from the manifest, which is a
long way from the missing annotation. Inferring it means the failure can't happen.

**The cost is devirtualization.** A decorator drew a line between framework-reachable
classes, which can't be devirtualized, and internal ones, which can. Without it, the
conservative reading is that nothing in the file devirtualizes.

That's a compiler question rather than a language one, and whole-program analysis answers
it better than an annotation did: a class not named in the manifest, not inflated from XML,
and not reachable from any foreign-facing signature can be devirtualized regardless of what
the source says. The decorator was asking the author to hand-compute reachability, which is
exactly the kind of thing the author gets wrong and the compiler doesn't.

Where analysis can't see — a class named only by a reflective string, a
`Class.forName` in a library — the answer is a build-level keep rule, the same mechanism
R8 already needs for the same reason. That's the honest place for it: reflection is a build
fact, not a type-system fact.

---

## Foreign Declarations

```vertex
declare module "android.widget" {
  export declare class Sample001 {
    constructor()
    sample002(a: int32): void
  }
}
```

Taken entirely on trust and lowered to method references and invocations. The compiler
never reads a class file. Three things must match the real class exactly: **binary name**
(`Outer$Inner` nesting included), **descriptor**, and **nullability**.

### Hierarchy

Foreign classes may declare `extends`, describing a hierarchy that already exists rather
than creating one.

```vertex
declare module "android.app" {
  export declare class Sample001 { }
  export declare class Sample002 extends Sample001 { }
}
```

A Vertex class may extend a foreign one — the single exemption to "classes have no
inheritance." It exists because `Activity`, `Service`, `View`, and `RecyclerView.Adapter`
are all subclass-or-nothing APIs, and no interface route is offered.

### Interfaces

`interface` / `implements`. Default methods declare with a body.

### Functional Interfaces

A SAM interface is an ordinary function type; the compiler emits the implementing class.

A captured `this` is a strong reference held for the implementing object's lifetime. That's
the leak `weak_ptr` above exists for, and it's worth stating plainly because the syntax
gives no hint — a lambda passed to a listener registration looks like nothing at all.

### Overloads

All but one overload of a shared name needs a descriptor string:

```vertex
declare module "android.widget" {
  export declare class Sample001 {
    sample002(a: int32): void
    "sample002(Ljava/lang/String;)V"(a: string): void
  }
}
```

Called as `a["sample002(Ljava/lang/String;)V"](b)`.

### Exceptions

The host runtime unwinds; Vertex doesn't. A throwing method is a return union, told rather
than inferred:

```vertex
declare module "java.io" {
  export declare class Sample001 {
    sample002(a: string): Sample003 | Sample004
  }
}
```

An unlisted checked exception that fires anyway panics rather than silently dropping.

### Nullability

Java references are nullable by default; Vertex bindings aren't. Absence is spelled
explicitly, and `if let` is the ordinary unwrap:

```vertex
if let a = Sample001.sample002(b) {
  a.sample003()
}
```

`instanceof` narrows exception unions. The two appear side by side where a call can both
fail and return null.

### Generics

A foreign generic class declares with type parameters; Vertex monomorphizes, erases at the
boundary, and takes a checked cast on return. `const N: usize` parameters can't cross.

---

## Worked Example

```vertex
namespace mainscreen

use host
use android

declare module "android.app" {
  export declare class Activity {
    constructor()
    setContentView(a: int32): void
    findViewById(a: int32): View | null
  }
}

declare module "android.view" {
  export declare class View {
    setVisibility(a: int32): void
  }
  export interface OnClickListener {
    onClick(a: View): void
  }
}

declare module "android.widget" {
  export declare class Button extends View {
    setOnClickListener(a: OnClickListener): void
  }
}

class MainActivity extends Activity {
  private label: weak_ptr<View> | null

  onCreate(): void {
    this.setContentView(R.layout.main)

    if let button = this.findViewById(R.id.submit) {
      button.setOnClickListener((a: View) => {
        if let live = this.label.lock() {
          live.setVisibility(0)
        }
      })
    }
  }
}
```

This exercises a bare package specifier with no scheme, a Vertex class extending a foreign
one with no decorator on it, `if let` narrowing a nullable `findViewById`, a SAM interface
as a function type, and `weak_ptr` guarding a view reference captured by a listener that
outlives the layout pass.