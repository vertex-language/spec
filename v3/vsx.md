# vsx.md

## What This Is

`.vsx` is Vertex with one addition: an **element expression**. Nothing else changes — same
types, same `use` slots, same numerics, same memory models. An element is syntax for a
call, and that is the whole feature.

```vertex
<Button text="Submit" onClick={handler} />
```

means

```vertex
Button({ text: "Submit", onClick: handler })
```

There is no element type, no virtual DOM, no diffing model, no `JSX` namespace, no
intrinsic-element table. Those are library concerns, and every target has different answers
to them.

**The extension is the switch, same as `.tsx`.** It can't be a `use` line: `use` never
selects anything — it asserts something the build already knows and errors when they
disagree (use.md). A grammar can't be selected by a line whose entire job is to be checked.
So the file name carries it, and a `.vsx` file is otherwise checked exactly like any other
file under whatever platform line it names.

---

## Lowering — One Rule

```
<Name a={x} b="s"> c1 c2 </Name>    ≡    Name({ a: x, b: "s" }, c1, c2)
<Name />                            ≡    Name({})
```

Attributes become a single object literal in first position. Children become trailing
positional arguments. `Name` is resolved by ordinary name resolution.

Everything follows from that:

- **No tag table.** `div` isn't special and neither is `Button`. A lowercase tag is an
  ordinary identifier that resolves or doesn't. There is no `IntrinsicElements`, because
  there is no universal `createElement` to register against — the same reasoning android.md
  gives for having no special Android namespace.
- **No factory, no pragma, no config.** JSX needs `jsxFactory` because the tag is a string;
  here the tag *is* the callee.
- **Typechecking is parameter checking.** The props literal is checked against the callee's
  first parameter and the children against its rest parameter. No `ElementAttributesProperty`,
  no `ElementChildrenAttribute` — those exist to recover a signature JSX threw away.
- **The return type is whatever the function returns.** A `View` on `android`, an `Element`
  on `js`, a `mutable_ptr<GtkWidget>` on `linux`.
- **It adds no types**, so it's legal under every platform including `any` — the same shape
  of claim js.md makes about `js` adding reach rather than types.

Dotted names fall out of Go-form imports for free:

```vertex
import "app/ui/widgets"

<widgets.Button text="ok" />        ≡    widgets.Button({ text: "ok" })
```

Children iterate as an ordinary rest parameter. native.md's "rest parameters are call-shape,
not a collection" is a C-ABI fact about extern declarations; it doesn't reach a Vertex
function:

```vertex
export func Column(props: readonly ColumnProps, ...children: View): View {
  var a = LinearLayout()
  for c in children {
    a.addView(c)
  }
  return a
}
```

---

## Restricted Forms

`.tsx` had to give things up to make `<` unambiguous. So does `.vsx`, plus a few Vertex
removes on their own merits.

**Angle-bracket type assertion.** `<T>expr` is not derivable. `as` is the sole spelling,
which numerics.md already treats as the only one worth documenting.

**Generic arrows need disambiguation.** `<T>(a: T) => a` is an element. Write `<T,>` or a
constraint:

```vertex
<T,>(a: T) => a
<T extends Sample001>(a: T) => a
<const N: usize>(a: array<int32, N>) => a      // already unambiguous — `const` can't start a tag
```

**Bare attribute shorthand removed.** `disabled` does not mean `disabled={true}`. It reads
as a name, and `{true}` costs four characters to say what was happening anyway — the same
trade numerics.md takes on implicit widening.

**Namespaced and hyphenated tags removed.** `<svg:rect>`, `<my-element>`. Neither is an
identifier, and there's no string-tag form to fall back to.

**Fragments removed.** `<>…</>` has no name, so there's nothing to call. A toolkit that
wants one exports an ordinary `Fragment` function.

**Attribute strings are ordinary `StringLiteral`s.** JSX gave them their own literal grammar
— no escapes, HTML entities instead. There was never a reason for two string lexers, and
entities assume a target that only one platform has.

**Spread.** `{...a}` in attribute position merges field-wise at compile time against the
props type. In *child* position it's removed — a dynamic child count needs a collection
type, and which collections exist differs per target (see open questions).

### Text Children

Two rules, no trimming and no collapsing:

1. A text run that is entirely whitespace is not a child.
2. Any other text run is a child, verbatim, and **must not contain a `LineTerminator`**.

```vertex
<Label>Submit</Label>                    ≡  Label({}, "Submit")

<Column>
  <Label>Submit</Label>
</Column>                                ≡  Column({}, Label({}, "Submit"))

<Label>
  Submit
</Label>                                 // error — text child spans lines
```

Multi-line text is a string literal in an expression container: `{"…"}`. This is
deliberately the opposite of JSX, which trims and collapses by a rule almost nobody can
state. Rule-driven rather than error-driven, same standard §1.8 held the terminator to.

`<`, `>`, `{`, `}` in text must be written as `{"<"}` and friends.

---

## Terminator Interaction

§1.8's rule needs two amendments, and both make multi-line elements work without the
wrapping parens JS requires.

**Added to the tokens that can end a statement:** the `>` of a *closing* tag, and `/>`. The
`>` of an opening tag is not one — children follow it.

**Added to the containers that are *not* statement-or-member:** the attribute list, the
child list, and the expression container `{ … }`. So no `Terminator` is inserted anywhere
inside an element.

```vertex
return <Column spacing={8}>
  <Label text={title} />
  <Button text="Submit" onClick={onTap} />
</Column>
```

That parses as one statement. The parens JSX needs are an ASI artifact, and Vertex doesn't
have ASI.

**`return` must be on the same line as `<`.** §1.8 inserts after `return` otherwise, and
the result is a `void` return with dead code below it. This is the classic trap, reproduced
here on purpose: the rule is stated, so the failure is predictable rather than magic.

An expression container holds one `AssignmentExpression`. `if`, `for`, and `switch` are
statements and are not spellable in child position — conditionals are `? :`, and repetition
is a function call.

---

## Grammar Diff

Diff against `vertex_fork_ts_diff.md`. Applies only to `.vsx`.

**Adds** to `PrimaryExpression`:

```
Element:
    < ElementName {Attribute} />
    < ElementName {Attribute} > {Child} </ ElementName >

ElementName:
    IdentifierReference {. IdentifierName}

Attribute:
    IdentifierName = StringLiteral
    IdentifierName = { AssignmentExpression }
    { ... AssignmentExpression }

Child:
    Text
    { AssignmentExpression }
    Element
```

The two `ElementName`s must match textually.

**Removes** `TypeAssertion: < Type > UnaryExpression`.

**Removes** from the TSX baseline: `JSXFragment`, `JSXNamespacedName`, the bare-attribute
arm of `JSXAttribute`, `JSXSpreadChild`, `JSXText`'s entity decoding, and `JSXAttributeValue`'s
private string grammar.

**Amends** §1.8 as above.

---

## Per Target

The syntax is portable. The toolkit isn't — and that's the honest description of the
situation, not a gap.

| Platform | Element returns | Tree built by | Notes |
|---|---|---|---|
| `android` | `View` | `addView` | sized props (`int32`), `weak_ptr` for captured `this` |
| `js` | `Element` | `appendChild` | `int` only — no sized props |
| `linux` | `mutable_ptr<GtkWidget>` | `gtk_box_append` | flat `declare module "gtk-4"` |
| `darwin` | `shared_ptr<NSView>` | `addSubview` | `framework:AppKit`, `@objc` |
| `windows` | a realize thunk | see below | Win32 builds top-down |
| `wasm` | — | — | no host UI surface to call into |
| `any` | whatever you define | — | portable component functions, no toolkit |

### `android`

```vertex
namespace mainscreen

use host
use android

import "app/ui/androidwidgets"

func submitScreen(title: string, onTap: (a: View) => void): View {
  return <Column spacing={8}>
    <Label text={title} />
    <Button text="Submit" onClick={onTap} />
  </Column>
}
```

`onTap` is a SAM interface, so a lambda passed here is a strong reference held for the
listener's lifetime — the leak android.md's `weak_ptr` section exists for, and the element
syntax gives even less hint of it than a bare call did.

Props types are the one snag: `struct` lowering is unresolved on `android`, so props are a
`class` or an object-literal-typed interface there until that's settled.

### `js`

```vertex
export func Button(props: readonly ButtonProps, ...children: Element): Element {
  let a = document.createElement("button")
  a.textContent = children[0]
  a.addEventListener("click", props.onClick)
  return a
}
```

Every numeric prop is `int`. A component written against `android`'s `int32` doesn't move
here, and shouldn't pretend to.

### `windows`

Win32 is where the model earns its keep. `CreateWindowExW` takes the parent handle at
creation, so the tree is built top-down — but an element expression evaluates children
before the parent. A wrapper returns a description instead of a widget:

```vertex
struct Node {
  realize: (parent: HWND) => HWND
}
```

Nothing in the language had to know. That's the argument for keeping the lowering at "one
call" rather than baking in construct-then-append: a target whose native tree runs the other
direction returns a thunk, and the syntax is unchanged.

---

## Open Questions

- **Object literal → nominal `struct` assignability.** The whole props story leans on it,
  and it's the one type-system question vsx doesn't answer for itself. Also blocked on
  android's `struct` lowering.
- **Dynamic child lists.** Spread children are removed because `span<T>`/`vector<T>` are
  native-only, and what a host target's collection type even is isn't written down anywhere
  yet. Until it is, repetition in a child list has no spelling.
- **Text children.** Verbatim-plus-no-newlines is the strict reading. The alternative is
  JSX's trim-and-collapse, which is friendlier and unstateable. Not reopening without a
  case.
- **`key`.** Deliberately not special. It's a prop like any other, and it only means
  something to a toolkit that reconciles.
- **Whether the removal of `<T>expr` should be language-wide** rather than `.vsx`-only. Two
  spellings for a static assertion is already one too many.