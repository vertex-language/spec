# types.md

## Struct Declaration
Value type. Fixed layout, copied by default, initialized by direct call rather than a
pointer-family construction call.

```vertex
struct Sample001 {
}
```

## Class Declaration
Reference type. Heap-allocated with an inline refcount header. Constructed with
`Sample001()` in the Managed tier; via `make_unique<Sample001>(...)` / `make_shared<Sample001>(...)`
in the Unmanaged tier — see `pointers.md`.

```vertex
class Sample001 {
}
```

## Readonly Field
Freezes a field's data independent of the binding's `var`/`let` mutability.

```vertex
struct Sample001 {
  readonly x: int32;
}
```

## Access Modifier Field
Visibility modifier on a class member.

```vertex
class Sample001 {
  private x: int32;
}
```

## Implements Clause
Declares interface conformance. Classes have no inheritance, so this is the sole route to polymorphism.

```vertex
class Sample001 implements Sample002 {
}
```

## Generic Type Constraint
Bounds a type parameter to an interface.

```vertex
func sample001<T extends Sample002>(a: T): T {
  return a;
}
```

## Const Generic Parameter
Binds a compile-time value as a type parameter. Usable directly in value position within the body.

```vertex
struct Sample001<T, const N: usize> {
  private storage: FixedArray<T, N>;
}
```

## Structural Copy
Assignment of a value type performs a memberwise copy, not aliasing. `let` is sufficient
here — the binding itself is never reassigned, only the underlying data is duplicated at
the point of assignment.

```vertex
let a = Sample001(0, 0);
let b = a;
```

## Move
Transfers ownership of a move-only binding, poisoning the source. The destination binding
is typically `var` if the moved-into value will itself be mutated afterward; `let` is legal
when it will not.

```vertex
var a = Sample001(0, 0);
var b = move(a);
```

## Passing Modes
Prefix type operators that pass a value type without copying it. Unannotated parameters copy; `move(a)` at the call site consumes.

```vertex
func sample001(a: mutating Sample002): void {
  a.x = 1;
}

func sample002(a: readonly Sample003): int32 {
  return a.x;
}
```

The two modes are not the same kind of thing, and after the rename they no longer look like it. `readonly` is an optimization — it and an unannotated parameter mean the same thing, minus the memcpy. `mutating` is the only route to mutating a caller's value type; it is the sole mode that changes what the program means.

The spellings come from different places, which is why they read differently. `readonly` is TypeScript's, extended to a new set of types (TS applies it to array and tuple types; Vertex applies it to struct types). `mutating` has no TS ancestor — reference semantics made the concept unnecessary there — so it falls through to the concept's English name, the same route that produced `destructor`.

`readonly` occupies two binding sites, disambiguated by position exactly as in TS: before an identifier it is a member modifier (`readonly x: int32`), following a `:` it is a prefix type operator (`a: readonly Sample003`). `mutating` is contextual rather than reserved, legal only following `:` in a parameter, return, or `this`-parameter annotation; `var mutating = 0` remains a legal binding.

## Passing Mode Position
Legal only in parameter, return, and `this`-parameter position. Never a local binding, never a field — a passing mode is not a first-class type and cannot be written as a type argument.

```vertex
struct Sample001 {
  sample002(this: readonly Sample001): int32 {
    return this.x;
  }
  sample003(this: mutating Sample001): void {
    this.x = 1;
  }
}

interface Index<I, T> {
  [Symbol.index](i: I): mutating T;
}
```

Swift spells `mutating` on the method declaration; Vertex spells it on the `this` parameter. Same word, different binding site. Note that Swift's parameter-position mode for caller-visible mutation is `inout`, not `mutating` — the receiver keyword is the only part Vertex shares.

In return position the mode reads from the caller's side, not the callee's: `: readonly T` means the caller receives something it cannot write through. `: mutating T` means the caller receives the ability to mutate — not that the function is mutating anything by returning it. This is the one position where `mutating` reads less directly than `readonly`, since the two positions look from opposite sides; parameter position is the common case and the one the spelling is optimized for.

## Passing Mode Restrictions
- **Value types only.** A `class` binding is already a reference; mutation through it needs no annotation. Class-side immutability is expressed with `readonly` fields. Pointer types (`shared_ptr<T>`, `unique_ptr<T>`, `mutable_ptr<T>`) never take a passing mode — they pass a handle by copy, and writes through the handle reach the same object regardless.
- **Shallow.** `readonly Sample001` freezes the struct's own fields. A `mutable_ptr<T>` member remains writable through — the mode describes the parameter, not the reachable graph.

```vertex
struct Sample001 {
  x: int32;
  data: mutable_ptr<uint8>;
}

func sample002(a: readonly Sample001): void {
  a.x = 1;         // error — a's own fields are frozen
  a.data[0] = 1;   // legal — the mode does not reach through the pointer
}
```

- **Non-escaping.** A borrow may be passed downward but never stored. `constructor(private x: mutating Sample001)` is therefore an error: TS parameter-property syntax would escape it into a field.
- **No exclusivity guarantee.** Unlike Rust's `&mut`, `mutating` does not imply unique access. Two `mutating` parameters may alias the same value, and a `mutable_ptr<T>` member may alias through a `readonly` one.
- **No call-site marker.** `mutating` is declaration-side only; `sample001(a)` does not signal that `a` is rewritten. This is C++'s `Rect&` wart, mitigated by non-escapingness — the effect is bounded to the callee and what it forwards to. A call-site marker is additive and can be introduced later without breaking existing code.