# jvm.md

## Scheme-Qualified Specifier

`jvm:` resolves through the JVM's class loader rather than the ordinary linker path. The
scheme is a prefix, matching `node:`, `bun:`, `npm:`, and URI convention generally.

The text after the scheme is a **package name**, not a class name:

    "jvm:java.util"  →  the java.util package

Package names are external identifiers fixed by the vendor, so they are written literally
throughout this document rather than as `Sample00N` placeholders. Names declared *from* a
package are Vertex-side and stay placeholders. Case is significant.

The specifier remains a string literal, so an unknown scheme is a resolution error, not a
parse error.

```vertex
declare module "jvm:java.util" {
  export declare class Sample001 {
  }
}
```

| Specifier | Resolver | Bound |
|---|---|---|
| `"jvm:java.util"` | JVM class loader | first use |

The scheme is named for the runtime, not the language. Kotlin, Scala, and Java all present
the same surface through it, and on Android the majority of what gets bound was never Java
source. Calling it `java:` would name the least interesting of its producers.

## Binding

There is no separate import. The `declare module` block is both the declaration and the
binder: names marked `export` inside it enter file scope directly. Same rule as `objc.md`
and `extern.md`.

A declaration needed in more than one file goes in a Vertex module that holds the block:

```vertex
import "app/platform/android"
```

This target makes the rule cheaper than it looks. An Android program touches seven or eight
packages in a single file, and the removed import lines were duplicating names that the
block below them already declared.

## Target Selection

Unlike `use cuda`, this is not a file-scoped choice. Half a program cannot be refcounted
while the other half is collected, so the target is a build setting for the whole program.
`use jvm` is legal as an assertion that a file expects the target, and is an error if the
build says otherwise. It selects nothing.

```vertex
use jvm
```

A `declare module "jvm:…"` block is legal only under this target, the same rule
`modules.md` states for a `cuda_intrinsics` import in a `use metal` file.

## Linkage

There isn't any. This is the first scheme whose `declare module` block does **not** drive a
link edge, because the JVM has no link step — classes resolve by name from the classpath on
first use. A `jvm:` block therefore binds like `"dynamic:"` in `extern.md`, not like
`"objc:"`.

Consequence, inherited directly from the dynamic form: a class or member that is not present
at runtime **panics at first use**. `NoClassDefFoundError` and `NoSuchMethodError` are the
same tier as a failed assertion, and skip teardown for the same reason.

Classpath composition is build configuration and lives outside the language.

## Object Model Under This Target

The target replaces Vertex's ownership model with the host's collector. The spellings
survive so that source stays portable; their meanings collapse.

| Spelling | Meaning on the JVM target |
|---|---|
| `shared_ptr<T>` | ordinary reference; the collector owns it |
| `weak_ptr<T>` | `java.lang.ref.WeakReference` |
| `unique_ptr<T>` | **error** — the runtime cannot promise uniqueness |
| `.lock()` | `WeakReference.get()`, still nullable, still the only route |

`unique_ptr` is rejected rather than silently downgraded, on the same reasoning `objc.md`
uses to reject it for foreign objects.

Cycles are collected. `weak_ptr` is therefore no longer required for correctness of
deallocation — but remains required wherever a live root outlives the object it points
back to, which on Android is the common case rather than the exotic one.

## Destructor

`destructor` is an error under this target.

This is the sharpest edge in the document and it is not a syntax problem. Vertex's teardown
is deterministic and scope-bound; the JVM's is neither. Finalizers are gone, and `Cleaner`
runs on an unspecified thread at an unspecified time — near enough to never for anything a
`destructor` is usually written to do. Mapping one onto the other would compile and then
quietly not happen.

Scope-bound release for foreign resources needs an explicit construct instead, of the
`try`-with-resources shape. Not yet spelled — see *Open Questions*. Until it exists, cleanup
is written by hand on every exit path.

## Value Types

`struct` is where the target hurts. The JVM has no value types before Valhalla, so a
`struct` must lower to a class — and `types.md`'s structural copy then silently becomes
aliasing, which changes what programs mean rather than what they cost.

Three routes, none free:

1. **Defensive copy** at every binding, parameter, and assignment. Semantics preserved,
   allocation everywhere.
2. **Scalarize.** Flatten fields into locals and parameters where the struct does not
   escape. Correct and fast in the common case; falls back to (1) at escape points.
3. **Require a Valhalla-capable JVM** and emit value classes. Rules out Android entirely
   for the foreseeable future.

Passing modes fall out of whichever is chosen. `readonly` becomes a no-op, which is
consistent with `types.md` describing it as an optimization. `mutating` requires the callee
to observe the caller's storage, which under (1) it does not and under (2) it does only
while the value stays scalarized — so it is the mode that changes what the program means
and the one that cannot be quietly approximated. Provisionally, `mutating` on a struct
parameter is an error under this target.

## Unmanaged Tier

Not available. `mutable_ptr`, `const_ptr`, `void_ptr`, `addressof`, `pointer_from_address`,
`pointer_cast`, pointer arithmetic, `sizeof`/`alignof`/`offsetof`, `@packed`, `@bits`, and
the C-union blob from `memory.md` are all errors — the same shape of subsetting
`use freestanding` already performs.

`span<T>` and `block<T>` are the exception, and survive by lowering to
`java.lang.foreign.MemorySegment`. `volatile_load`/`volatile_store` map to `VarHandle`
accessors; `unaligned_load`/`unaligned_store` map to unaligned segment access. `bit_cast`
maps to the `Float.floatToRawIntBits` family where a pair exists, and is otherwise an error.

Note that this exception is the least portable part of the document: `java.lang.foreign` is
recent on the JVM and later still on Android, so `span` and `block` may be unavailable on
the very profile this target exists to serve.

## Numerics

The JVM has no unsigned types. `uint8`…`uint64` lower to the same-width signed primitive
with the operations reinterpreted — `Integer.divideUnsigned`, `Long.compareUnsigned`, and
the rest. Representation is shared, semantics are not, and `bit_cast` between a signed and
unsigned pair is free by construction.

- `usize` is `long`.
- `int8`/`int16` are `byte`/`short` in fields and arrays, widened to `int` in arithmetic and
  re-narrowed on store.
- `int32`/`int64` are `int`/`long`.
- `float32`/`float64` are `float`/`double`.
- `bool` is `boolean`. The absence of integer-boolean conversion in `numerics.md` costs
  nothing here, since the JVM agrees — `if (a)` on an `int` is already an error in Java.
- `byte` is `byte`.
- `int` — unresolved, see below.

### The `int` problem

`grammar_notes.md` renames TS's `number` to `int`, and `numerics.md` carries that through:
`int` is the unsized default, distinct from `int32`. Under TS semantics its value is a
double.

That leaves this target stating "`int` is `double`", which is not a mapping so much as a
contradiction sitting in the type name. Worse, it is a contradiction on every other target
too — this one just makes it visible, because the JVM forces a choice of primitive where
native codegen could stay vague.

Three ways out, and none of them belong in this document:

1. **`int` is `int64`.** The rename becomes a real integer type, and TS's double-valued
   `number` is gone. Cleanest reading of the name; breaks the "straight rename" framing in
   `numerics.md`.
2. **`int` is `float64`.** The name lies but the semantics are inherited intact. Hard to
   defend next to `int8`…`int64` in the same list.
3. **`int` is removed.** Sized types only; the unsized default disappears with the language
   it came from.

This needs settling in `numerics.md` before this section can say anything. Listed under
*Open Questions* below, but it is not a JVM question.

## Foreign Module Declaration

One block per package, declaring the subset of its surface the program uses.

```vertex
declare module "jvm:java.util" {
  export declare class Sample001 {
    constructor()
    sample002(a: int32): void
  }
}
```

## Declaration Fidelity

The compiler does not read class files. Everything inside the block is taken on trust and
lowered directly into method references and invocations — a signature that disagrees with
the real class produces a failure at first use, not a diagnostic. Same trust model as
`objc.md` and `extern.md`.

Three things must match exactly:

- **Binary name**, including package and `Outer$Inner` for nested types.
- **Descriptor**, at JVM granularity — `int32` and `int64` are not interchangeable.
- **Nullability**, since Vertex bindings are non-nullable unless a union says otherwise.

## Foreign Class Hierarchy

Foreign ambient classes may declare `extends`. As in `objc.md`, this is not an exception to
"classes have no inheritance" — the hierarchy already exists in the runtime, and the clause
describes it rather than creating it.

```vertex
declare module "jvm:java.util" {
  export declare class Sample001 { }
  export declare class Sample002 extends Sample001 { }
}
```

Beyond that, a **Vertex-side class may extend a foreign one**, and only a foreign one.
`objc.md` never needed this because delegation covers Cocoa; Android does not offer that
option, since `Activity`, `Service`, `View`, and `RecyclerView.Adapter` are all extended
rather than implemented. The exemption is narrow: the base must be a foreign ambient class,
and Vertex-side hierarchies remain illegal. Without it the target cannot express an Android
app, which makes this the one item in the document that cannot be deferred.

## Interfaces

A Java interface is an `interface`; conformance is `implements`. Unchanged from `types.md`,
and the cleanest correspondence in the document. Default methods declare with a body in the
ambient block and are inherited normally.

## Functional Interfaces

An interface with a single abstract method is an ordinary function type at the use site, the
same way an Objective-C block is in `objc.md`. The compiler emits the implementing class;
`invokedynamic` and `LambdaMetafactory` are lowering details.

```vertex
declare module "jvm:java.lang" {
  export declare class Sample001 {
    constructor(a: () => void)
  }
}
```

Capture is by value, and a captured `this` is a strong reference held for as long as the
implementing object lives. This is not the retain cycle `objc.md` warns about — the
collector handles cycles — but it is the same practical leak, and on Android it is *the*
leak.

## Overloads

Java overloads on parameter types; Vertex does not. Where a class has several methods
sharing a name, all but one are declared by **descriptor string** — the direct analogue of
`objc.md`'s string-literal method declaration, and the same escape hatch for the same
reason.

```vertex
declare module "jvm:java.util" {
  export declare class Sample001 {
    sample002(a: int32): void
    "sample002(Ljava/lang/String;)V"(a: string): void
  }
}
```

Call sites use the ordinary member expression for the bare form and the computed form for
the rest: `a["sample002(Ljava/lang/String;)V"](b)`.

## Exceptions

The JVM unwinds; `control_flow.md` does not. At the boundary, a foreign method that throws
is spelled as a return union — told rather than inferred, the same position `objc.md` takes
on `NSError**`.

```vertex
declare module "jvm:java.util" {
  export declare class Sample001 {
    sample002(a: string): Sample003 | Sample004
  }
}
```

The generated stub catches at the boundary and returns. A checked exception left out of the
union that fires anyway is a panic, not a silent drop.

The compiler *could* read `throws` clauses off the class file, and does not, for the reason
`objc.md` gives about Swift's importer: Vertex is told, so it infers nothing.

## Nullability

Java references are nullable by default; Vertex bindings are not. An ambient declaration
must therefore spell absence explicitly. A `@NonNull`-annotated or JSpecify null-marked API
maps to the bare type; everything else takes the union. Identical rule to `objc.md`,
identical failure mode when it is wrong.

`if let` is the ordinary route to a nullable foreign result:

```vertex
if let a = Sample001.sample002(b) {
  a.sample003()
}
```

Note that `if let` covers absence, not narrowing. An exception union is narrowed with
`instanceof`, which is a different shape and stays explicit — the two appear side by side
throughout the example below.

## Generics

Java generics are erased and Vertex's are monomorphized, so they do not meet. A foreign
generic class declares with its type parameters; the binding monomorphizes on the Vertex
side, erases at the call boundary, and takes a checked cast on return. `const N: usize`
parameters have no representation and cannot cross the boundary in either direction.

## `@jvm` Class Decorator

Marks a Vertex class as dispatchable from the host runtime. Under this target every class is
already a JVM object, so unlike `@objc` this changes nothing about allocation — it changes
*emission*: a real named class file with a stable binary name, public members, and no
devirtualization of anything reachable from outside.

```vertex
@jvm class Sample001 implements Sample002 {
}
```

## API Level

Not spelled in Vertex source, for the reason `objc.md` gives about availability: version
ranges the compiler cannot see, on declarations it does not own. Android's API levels are
the same problem wearing different clothes, and take the same answer — a sidecar keyed by
package, in the shape of Clang's `.apinotes`.

## Grammar Cost

Zero, and for once that is not the interesting number. Every production here already exists:
scheme specifiers are string literals, `declare module` and `export declare class` and
ambient `extends` are existing productions, descriptor sends are computed member calls,
exception conventions are return unions.

The cost of this target is semantic. It deletes `destructor`, deletes the unmanaged tier,
deletes `unique_ptr`, suspends `mutating`, and puts `struct` copy semantics in question.
Those belong in a capability matrix, not in `grammar_diff_v2.md`. The split is not
native-versus-managed — wasm sits with native, keeping pointers and deterministic teardown —
so the tier a package requires is worth declaring up front rather than discovering three
layers deep in a build.

---

# Worked Example: Android

An `Activity` that fetches a URL off the main thread and writes the result into a
`TextView`. Seven packages, so seven blocks.

```vertex
namespace mainactivity

use jvm

declare module "jvm:java.lang" {
  export declare class Thread {
    constructor(a: () => void)
    start(): void
  }

  export declare class String {
    constructor(a: span<byte>)
  }
}

declare module "jvm:java.io" {
  export declare class IOException {
    readonly message: string | null
  }

  export declare class InputStream {
    readAllBytes(): span<byte> | IOException
    close(): void | IOException
  }
}

declare module "jvm:java.net" {
  export declare class URL {
    constructor(a: string)
    openStream(): InputStream | IOException
  }
}

declare module "jvm:android.os" {
  export declare class Bundle { }
}

declare module "jvm:android.view" {
  export declare class View {
    setOnClickListener(a: OnClickListener | null): void
  }

  export interface OnClickListener {
    onClick(a: View): void
  }
}

declare module "jvm:android.widget" {
  export declare class TextView extends View {
    "setText(Ljava/lang/CharSequence;)V"(a: string): void
    "setText(I)V"(a: int32): void
  }
}

declare module "jvm:android.app" {
  export declare class Activity {
    onCreate(a: Bundle | null): void
    setContentView(a: int32): void
    findViewById<T extends View>(a: int32): T | null
    runOnUiThread(a: () => void): void
  }
}

@jvm class MainActivity extends Activity implements OnClickListener {
  private label: TextView | null

  onCreate(a: Bundle | null): void {
    super.onCreate(a)
    this.setContentView(0x7f0b_0001)

    this.label = this.findViewById<TextView>(0x7f0b_0002)

    if let button = this.findViewById<View>(0x7f0b_0003) {
      button.setOnClickListener(this)
    }
  }

  onClick(a: View): void {
    let self: weak_ptr<MainActivity> = weak_ptr(this)

    Thread((): void => {
      let stream: InputStream | IOException = URL("https://example.com").openStream()
      if stream instanceof IOException {
        return
      }

      let bytes: span<byte> | IOException = stream.readAllBytes()
      stream.close()
      if bytes instanceof IOException {
        return
      }

      let text = String(bytes)

      if let live = self.lock() {
        live.runOnUiThread((): void => {
          if let target = self.lock() {
            if let label = target.label {
              label["setText(Ljava/lang/CharSequence;)V"](text)
            }
          }
        })
      }
    }).start()
  }
}
```

## What the example exercises

- **A Vertex class extending a foreign one.** `MainActivity extends Activity` is the
  exemption in *Foreign Class Hierarchy*. Nothing about this program works without it,
  which is the argument for taking it.

- **Descriptor-string declarations, non-optionally.** `TextView.setText` has two overloads,
  and the wrong one is not a compile error in Java — `setText(int)` treats its argument as a
  resource ID. Picking by name silently means "look this up in `R.string`". Same motivating
  case as `objc.md`'s `webView:` collisions, with a sharper failure: a live app that renders
  garbage instead of failing at dispatch.

- **Both narrowing forms, adjacently.** `findViewById` and `.lock()` return nullables and
  take `if let`; `openStream` and `readAllBytes` return exception unions and take
  `instanceof`. The two read differently on purpose — one is absence, the other is a value
  of another type.

- **Exceptions as return unions.** `openStream` and `readAllBytes` are declared
  `throws IOException` upstream. Nothing is inferred from a `throws` clause the compiler
  could have read.

- **Nested binary names.** `OnClickListener` is `android.view.View$OnClickListener`,
  declared in the enclosing package's block. The Vertex-side spelling drops the nesting; the
  descriptor does not.

- **Erased generics.** `findViewById<TextView>` monomorphizes on the Vertex side and erases
  to `View` at the boundary, with a checked cast on return.

- **Functional interfaces as function types.** Both `Thread`'s constructor argument and
  `runOnUiThread`'s take arrow functions; the implementing classes are emitted.

- **A weak self-reference.** The `Thread` outlives the `Activity` on rotation. Capturing
  `this` strongly is the canonical Android leak — the collector does not help, because the
  thread is a live root. `weak_ptr` plus `.lock()` at each resumption point is the whole fix,
  and it reads identically to the delegate case in `objc.md` despite being a different
  failure.

- **Manual close, because there is no `destructor`.** `stream.close()` is written by hand
  before both `IOException` exits from the read. `objc.md`'s example could rely on teardown;
  this one cannot, and the duplication is exactly the cost *Destructor* describes.

## What the example did not resolve

- **Throwing constructors.** `URL(spelling)` throws `MalformedURLException` upstream and is
  declared here as though it cannot fail, which is wrong. `control_flow.md` spells
  fallibility as a return union, and a constructor has no return position. Either
  constructors gain a fallible form or throwing ones are declared as static factories.

- **`R` constants.** Layout and view IDs are written as literals because `R` is generated by
  `aapt` at build time and ships in no package. It needs either a generated `declare module`
  or a build-time constant import. A real gap, not a simplification for the example.

- **Overload declaration is all-or-nothing.** Both `setText` forms are declared by
  descriptor, since leaving one bare would make the call sites read inconsistently for no
  gain. Whether the bare form should be *allowed* when overloads exist is open.

- **`readAllBytes` and API level.** It lands on Android at API 33. Nothing in the source says
  so, per *API Level* — it lives in the sidecar, which does not exist yet.

- **Nesting depth.** The `if let` chain in `onClick` runs three deep at the UI-thread hop.
  Shorter than the null-check version it replaces, but the shape suggests a guard form
  (`else { return }` at the binding site) would earn its keep. Not proposed here.

---

## Open Questions

- **`int`.** Whether `int` is an integer, a double, or removed. Not a JVM question, but this
  target is where it stops being deferrable. Blocks *Numerics*.
- **Struct lowering.** Defensive copy, scalarization, or Valhalla. Blocks `mutating`.
- **Scope-bound resource release.** Needed once `destructor` is gone.
- **Throwing constructors.** Fallible constructor form, or static factories.
- **`R` constants.** Generated declarations for build-time resource IDs.
- **Arrays.** Whether `FixedArray<T, N>` lowers to a JVM array or is rejected in favor of
  `span`. Note `extern.md` has now dropped postfix `[]` entirely, which removes one
  candidate spelling from the question.
- **`string`.** Whether Vertex's string is `java.lang.String` under this target, and what
  that costs everywhere else. Sharpened by the example, which constructs a foreign `String`
  and passes it to a parameter typed `string` without comment.
- **Threads.** No memory model story yet; the JVM has a strong one and Vertex does not.
- **`span`/`block` on Android.** `java.lang.foreign` availability may remove the one
  surviving piece of the unmanaged tier on the profile that matters most.