# vertex_fork_ts.md

Diff against `typescript_grammar.md`. Only edits are listed — **an unlisted production is inherited unchanged**. Verdicts: **Adds** (new production), **Replaces** (old spelling no longer derivable), **Removes** (deleted, nothing replaces it).

---

## §1 Lexical

**Replaces** `ReservedWord`: `function` → `func`; adds `struct`.

**Removes** from `ContextualKeyword`: `of`, `from`, `require`, `defer` — each a terminal only of a production removed below.

**Adds** to `ContextualKeyword`: `use`, `kernel`, `graph`, `mutating`, `destructor`, `int`, `bool`.

**Adds** punctuator `..`. Maximal munch separates it from `.` and `...`.

### §1.8 Statement termination

**Replaces** automatic semicolon insertion and every *(no LineTerminator here)* restricted production.

```
Terminator:
    ;
    (inserted per rule below)
    (end of input)
```

A `LineTerminator` inserts a `Terminator` when **both** hold:

1. The preceding token can end a statement: any `Identifier`, `PredefinedType` terminal, `NumericLiteral`, `StringLiteral`, `NoSubstitutionTemplate`, `TemplateTail`, `RegularExpressionLiteral`, `true`, `false`, `null`, `this`, `)`, `]`, `}`, `++`, `--`, `!`, `return`, `break`, `continue`, and a `>` closing `TypeArguments`/`TypeParameters`.
2. The innermost unclosed bracket is a statement-or-member container: `Block`, `ClassBody`, struct body, enum body, `ObjectType`, ambient module body, `CompilationUnit` top level. Not `(`, `[`, `ObjectLiteral`, `TupleType`, `ParenthesizedTupleType`.

A `Terminator` may be omitted before a closing `}` or `)`.

Rule-driven, not error-driven: a line beginning `(` or `[` cannot silently continue the previous statement. `;` remains a vaild terminal everywhere.

---

## §2 Types

**Replaces** two `PredefinedType` entries: `number` → `int`, `boolean` → `bool`. List otherwise untouched.

`int8`…`float64`, `usize`, `byte` are ordinary `TypeIdentifier`s, not `PredefinedType` — required so `int32(a)` can parse as a call.

**Adds** to `TypeOperatorType`:

```
TypeOperatorType:
    ...
    mutating TypeOperatorType
```

`readonly TypeOperatorType` already exists; only its operand set widens (semantic).

**Adds** to `PrimaryType`:

```
ParenthesizedTupleType:
    ( Type , TypeList [,] )
```

≥2 elements, keeping it disjoint from `( Type )`. Resolution order for `( … )` in type position: `=>` after the closer → `FunctionType`; depth-0 comma → this; otherwise parenthesization.

**Adds** to `TypeParameter`:

```
TypeParameter:
    ...
    const BindingIdentifier TypeAnnotation
```

Distinguished from TS's `<const T>` modifier by the presence of `:`. One token of lookahead.

**Removes** `PostfixType [ ]`. Contiguous storage is `span<T>`, `block<T>`, `FixedArray<T, N>`. Indexed access `PostfixType [ Type ]` is unaffected.

---

## §4 Programs and Modules

**Replaces** `Script` / `Module` / `ModuleItem`:

```
CompilationUnit:
    NamespaceHeader {UseDirective} {TopLevelItem}
```

**Replaces** all of §4.1:

```
ImportDeclaration:
    import ImportSpec
    import ( {ImportSpec} )

ImportSpec:
    [ImportAlias] StringLiteral

ImportAlias:
    Identifier
    _
```

Gone: `ImportClause`, `ImportedDefaultBinding`, `NameSpaceImport`, `NamedImports`, `ImportSpecifier`, `FromClause`, `WithClause`, `WithEntryList`, `ImportEqualsDeclaration`, `type`-only forms, `defer`. No named-binding form is what makes `declare module` the sole source of foreign names.

The group needs no separator: after a spec's `StringLiteral` the next token is a `StringLiteral`, an `Identifier`/`_`, or `)`.

**Replaces** `ExportDeclaration`:

```
ExportDeclaration:
    export Declaration
    export BindingDeclaration
```

**Removes** `export NamedExports`, `export ExportFromClause FromClause`, `export default`, `export =`, `NamespaceExportDeclaration` — each produces a binding only the removed import forms could consume.

---

## §5 Declarations and Functions

**Replaces** `VariableStatement` + `LexicalDeclaration`:

```
BindingDeclaration:
    VarLetConst VariableDeclarationList

VarLetConst: (one of)
    var let const
```

All three are block-scoped; `var`/`let` differ in mutability, `const` is compile-time-only. The mandatory `;` is dropped from the production, not the language — §1.8 closes it.

**Replaces** `FunctionDeclaration` / `FunctionExpression`:

```
FunctionDeclaration:
    {Decorator} {FunctionModifier} func BindingIdentifier CallSignature
        FunctionBodyOrTerminator

FunctionModifier: (one of)
    kernel graph

FunctionBodyOrTerminator:
    Block
    Terminator
```

`{Decorator}` is new on functions. `FunctionBodyOrSemicolon` → `FunctionBodyOrTerminator` applies wherever the base file names it (`ConstructorDeclaration`, `MethodDeclaration`, accessors). Generator/async variants take the `function` → `func` swap only.

---

## §6 Classes and Structs

**Adds** a `Declaration` alternative:

```
StructDeclaration:
    {Decorator} struct BindingIdentifier [TypeParameters] { {StructElement} }

StructElement:
    {Decorator} {AccessibilityModifier} [readonly] ClassElementName TypeAnnotation
    ConstructorDeclaration
    MethodDeclaration
```

A subset of `ClassBody`: no `extends`, no static blocks, no accessors. `{Decorator}` on `StructElement` carries `@bits`.

**Adds** a `ClassElement` alternative:

```
DestructorDeclaration:
    destructor ( ) Block
```

---

## §7 Namespaces and Enums

**Replaces** `NamespaceDeclaration`:

```
NamespaceHeader:
    namespace NamespaceName
```

**Removes** `NamespaceBody` / `NamespaceElement` as reachable from here, along with the braced form and its internal export arms.

**Replaces** `EnumDeclaration` / `EnumMember`:

```
EnumDeclaration:
    enum BindingIdentifier [TypeParameters] [TypeAnnotation] { {EnumMember} }

EnumMember:
    EnumMemberName [= AssignmentExpression]
    EnumMemberName ( ParameterList )
```

Backing type via `TypeAnnotation`; `TypeParameters` are new; members are terminator-separated rather than comma-separated. The associated-value arm reuses `ParameterList` verbatim.

---

## §8 Statements

**Replaces** `IfStatement`, `IterationStatement`, `SwitchStatement` — parens dropped, body mandatory `Block`:

```
IfStatement:
    if ConditionExpression Block [else (Block | IfStatement)]
    if let BindingIdentifier = ConditionExpression Block [else (Block | IfStatement)]

IterationStatement:
    while ConditionExpression Block
    for ForBinding in ConditionExpression Block

SwitchStatement:
    switch ConditionExpression { {CaseClause} [DefaultClause] }

CaseClause:
    case AssignmentExpression {, AssignmentExpression} Block

DefaultClause:
    default Block
```

`ConditionExpression` is `Expression` with no unparenthesized `ObjectLiteral` at depth 0 — the price of paren-free heads, same as Go and Rust.

Consequences: `if x doA()` is not derivable; `case 0 :` and fallthrough are gone (comma lists replace grouped fallthrough); `for`-`in`, `for`-`of`, `for await`, and the C-style triple collapse into the one `in` form. `do`/`while` inherits the paren edit as `do Block while ConditionExpression`.

`if let` binds one identifier, no patterns. `let` is contextually reserved by position after `if`.

---

## §9 Expressions

**Adds**:

```
RangeExpression:
    AdditiveExpression .. AdditiveExpression
```

Operand level is provisional — see collisions.

---

## §10 Patterns

**Adds** to `BindingPattern`:

```
TupleBindingPattern:
    ( BindingElement , BindingElementList [,] )
```

≥2 elements, matching `ParenthesizedTupleType`.

---

## §11 Decorators

`Decorator` itself is unedited. What changes is where `{Decorator}` appears: added to `FunctionDeclaration` (§5), `StructDeclaration` and `StructElement` (§6). A decorator on its own line is not terminated away from its declaration — it is a declaration prefix, not a statement, so the parser is never at a boundary.

---

## §12 Ambient Declarations

**Adds** an `AmbientDeclaration` alternative:

```
AmbientStructDeclaration:
    struct BindingIdentifier
```

**Replaces** the body of `AmbientModuleDeclaration`:

```
AmbientModuleDeclaration:
    module StringLiteral { {ForeignModuleElement} }
    module StringLiteral Terminator

ForeignModuleElement:
    export AmbientFunctionDeclaration
    export declare AmbientClassDeclaration
    export InterfaceDeclaration
```

Narrowed from `NamespaceBody`'s full `StatementListItem` set — this is what makes "the block is the declaration and the binder" grammatical rather than conventional.

**Replaces** `AmbientFunctionDeclaration`: `function` → `func`, terminating `;` → `Terminator`.

Scheme prefixes (`dynamic:`, `objc:`, `jvm:`) live inside the `StringLiteral`. Zero grammar; an unknown scheme is a resolution error.

---

## §13 Directives

**Replaces** `DirectivePrologue`:

```
UseDirective:
    use Identifier
```

A string literal in statement position is now an ordinary expression statement; TS1347 has nothing left to constrain.