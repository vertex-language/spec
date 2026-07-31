# Vertex Language Grammar

## Annex A (normative) — Grammar Summary

Goal symbols: `SourceFile` (syntactic), `InputElement` (lexical).

---

## A.0 Notation

Vertex grammar notation is BNF-derived and closely modelled on the ECMAScript
grammar summary, with four extensions marked **(V)** below.

### A.0.1 Production forms

```
Nonterminal ::
    alternative                     — lexical production (:: )
    alternative

Nonterminal :
    alternative                     — syntactic production (: )

Nonterminal :: one of
    a b c d                         — each terminal is one alternative


```

`Symbolopt` means the symbol may be omitted; a production containing *n*
optional symbols abbreviates 2ⁿ productions.

`X but not Y` matches any X that is not also Y.

`[lookahead ≠ t]` / `[lookahead ∉ Set]` forbid the next input element from being
the given terminal or from being drawn from the given set.

`[empty]` matches no input.

### A.0.2 Context parameters **(V)**

Four parameters carry context through the syntactic grammar. They are the
mechanism by which function coloring, device targeting, ownership positions, and
composite-literal ambiguity are expressed grammatically rather than in prose.

| Parameter | Set by | Licenses |
| --- | --- | --- |
| `Await` | an `async`-marked function body, or `main` | the `await` operator (A.4.2) |
| `Npu` | an `npu`-marked function body | `tensor[...]` types and the `npu.` namespace (A.11.3) |
| `Own` | an owning position (A.9.1) | the `var` transfer marker (A.4.6) |
| `Lit` | any expression position that is not a control-flow header | a bare composite/map literal (A.4.7) |

A parameterized reference is written `Nonterminal[+P]`, `Nonterminal[~P]`, or
`Nonterminal[?P]` with the usual meanings. A guarded alternative
`[+P] alternative` exists only when the parameter is set; `[~P] alternative`
only when it is not.

Nothing else in Vertex is context-sensitive. Every other rejection this document
records is a static rule (A.0.4) checked over an already-parsed tree, not a
parse failure — a deliberate choice, because it keeps the parser table-driven
and lets diagnostics quote a well-formed source construct back to the reader
instead of a token position.

### A.0.3 Implicit propagation **(V)**

Unlike ECMAScript, a parameter that is **not** written on a right-hand-side
reference is propagated unchanged from the left-hand side. Only a *change* of
context is annotated. `Expression` inside `Block[+Await]` is therefore
`Expression[+Await]` without further marking. A parameterized reference explicitly
written as `[?P]` is permitted emphasis to indicate to the reader that the
parameter propagates, though it is not strictly required.

Propagation stops at a function boundary. A nested `FunctionExpression` (A.4.1)
begins with all four parameters cleared, and re-sets them from its own marker
list — an anonymous closure written inside an `async` body may not `await`
unless it is itself marked `async`.

### A.0.4 Static-rule lines — `⊢` **(V)**

A line beginning `⊢` states a rule the parser accepts but a later compiler phase
enforces. These are not productions; they are the side conditions attached to the
production immediately above.

### A.0.5 Error forms — `✗` **(V)**

A line beginning `✗` gives a form that parses but is rejected, together with the
diagnostic named in the corresponding specification document. Error forms are
part of the grammar because Vertex specifies its rejections as deliberately as
its acceptances.

### A.0.6 Statement termination

Vertex has no statement terminator token. A statement ends at a `LineTerminator`
or at the `}` closing its block. Where a production lists two symbols in
sequence, whitespace including line terminators may separate them unless a
`[no LineTerminator here]` restriction appears.

There is no automatic-semicolon-insertion machinery and no continuation rule: a
line break inside a bracketed group (`(`…`)`, `[`…`]`, `{`…`}`) is ordinary
whitespace, and a line break outside one ends the statement. Every multi-line
construct in this grammar is therefore bracket-delimited by construction.

---

## A.1 Lexical Grammar

```
SourceCharacter ::
    any Unicode code point

InputElement ::
    WhiteSpace
    LineTerminator
    Comment
    Token

Token ::
    Identifier
    Keyword
    Literal
    Punctuator

WhiteSpace :: one of
    <TAB> <VT> <FF> <SP> <NBSP> <ZWNBSP> <USP>

LineTerminator ::
    <LF>
    <CR> [lookahead ≠ <LF>]
    <CR> <LF>
    <LS>
    <PS>


```

### A.1.1 Comments

```
Comment ::
    SingleLineComment
    MultiLineComment

SingleLineComment ::
    // SingleLineCommentCharsopt

SingleLineCommentChars ::
    SingleLineCommentChar SingleLineCommentCharsopt

SingleLineCommentChar ::
    SourceCharacter but not LineTerminator

MultiLineComment ::
    /* MultiLineCommentCharsopt */

MultiLineCommentChars ::
    MultiLineNotAsteriskChar MultiLineCommentCharsopt
    * PostAsteriskCommentCharsopt

PostAsteriskCommentChars ::
    MultiLineNotForwardSlashOrAsteriskChar MultiLineCommentCharsopt
    * PostAsteriskCommentCharsopt

MultiLineNotAsteriskChar ::
    SourceCharacter but not *

MultiLineNotForwardSlashOrAsteriskChar ::
    SourceCharacter but not one of / or *


```

⊢ `MultiLineComment` does not nest; the first `*/` closes it.
⊢ A `Comment` containing a `LineTerminator` is itself a `LineTerminator` for the
purposes of A.0.6.

### A.1.2 Identifiers

```
Identifier ::
    IdentifierName but not one of Keyword or ReservedLiteralKeyword

IdentifierName ::
    IdentifierStart
    IdentifierName IdentifierPart

IdentifierStart ::
    UnicodeIDStart
    _

IdentifierPart ::
    UnicodeIDContinue
    _

UnicodeIDStart ::
    any Unicode code point with the Unicode property “ID_Start”

UnicodeIDContinue ::
    any Unicode code point with the Unicode property “ID_Continue”

BlankIdentifier ::
    _


```

⊢ `$` is not an identifier character in Vertex.
⊢ `BlankIdentifier` is legal only as a type-parameter name (A.7.1), an
enum-payload binding (A.5.6), or a discarded destructuring target.
It never introduces a usable binding.

### A.1.3 Keywords

```
Keyword :: one of
    abstract    as          async       await       break       case
    chan        class       constraint  continue    declare     default
    defer       else        enum        fallthrough for         func
    gpu         if          import      in          let         map
    mut         npu         package     return      select      shared
    struct      switch      tensor      thread      type        typed_ptr
    unique      var         weak        while

ReservedLiteralKeyword :: one of
    true        false       nil


```

`ReservedLiteralKeyword` tokens are `Literal`s syntactically (A.1.5) and
reserved words lexically: they may never be rebound.

```
ContextualKeyword :: one of
    build       deinit      error       framework   init        module
    test


```

A `ContextualKeyword` is an `Identifier` everywhere except the single production
that names it. `init` and `deinit` are ordinary method names in a receiver
declaration (A.6.4) and modifiers only inside a `declare` block (A.8.3);
`framework` and `module` are meaningful only immediately after `declare`;
`build` only as the second line-initial token of a source file (A.2.2); `test`
only in a function-marker position (A.6.1); `error` only inside `Expected`
(A.12.2).

⊢ A `ContextualKeyword` used as a plain identifier in a position where its
special meaning is also grammatical is resolved in favour of the special
meaning, and shadowing it there is a compile error rather than a silent
reinterpretation.

### A.1.4 Predeclared Names

Predeclared names are ordinary identifiers pre-bound in an implicit outermost
scope. They are **not** keywords: they may be shadowed by a user declaration,
except where marked reserved.

```
PredeclaredTypeName :: one of
    int     int8    int16   int32   int64
    uint    uint8   uint16  uint32  uint64
    byte    float32 float64 bool    char    string

PredeclaredConstraintName :: one of
    any     comparable

ReservedBuiltinName :: one of
    addr    alignof copy    delete  new     reinterpret
    resize  sizeof  zero    drop    upgrade transfer


```

⊢ `byte` and `uint8` denote the same type; no conversion is required or
permitted between them, in either direction.
⊢ A `ReservedBuiltinName` may **not** be shadowed, and may not be declared as a
member, method, or field name.
✗ `func (w: var Widget) new() { }` — `new` is a reserved builtin name, not a
declarable member.
✗ `func (p: typed_ptr int32) addr() { }` — likewise for `addr`.
✗ `x.transfer()` — the `.transfer()` spelling of ownership transfer is removed
from the language; the marker is the `var` prefix (A.4.6). The name stays
reserved so the diagnostic can carry a fix-it rather than degrading into
“no such method”.

### A.1.5 Literals

```
Literal ::
    NumericLiteral
    StringLiteral
    CharLiteral
    BooleanLiteral
    NilLiteral

BooleanLiteral :: one of
    true false

NilLiteral ::
    nil


```

#### A.1.5.1 Numeric literals

```
NumericLiteral ::
    IntegerLiteral
    FloatLiteral

IntegerLiteral ::
    DecimalIntegerLiteral
    BinaryIntegerLiteral
    OctalIntegerLiteral
    HexIntegerLiteral

DecimalDigit :: one of
    0 1 2 3 4 5 6 7 8 9

BinaryDigit :: one of
    0 1

OctalDigit :: one of
    0 1 2 3 4 5 6 7

HexDigit :: one of
    0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F

HexDigits ::
    HexDigit
    HexDigits HexDigit

DecimalIntegerLiteral ::
    DecimalDigit
    DecimalDigit DecimalDigitsWithSeparators

BinaryIntegerLiteral ::
    0b BinaryDigitsWithSeparators
    0B BinaryDigitsWithSeparators

OctalIntegerLiteral ::
    0o OctalDigitsWithSeparators
    0O OctalDigitsWithSeparators

HexIntegerLiteral ::
    0x HexDigitsWithSeparators
    0X HexDigitsWithSeparators

DecimalDigitsWithSeparators ::
    DecimalDigit
    _ DecimalDigit
    DecimalDigitsWithSeparators DecimalDigit
    DecimalDigitsWithSeparators _ DecimalDigit

BinaryDigitsWithSeparators ::
    BinaryDigit
    _ BinaryDigit
    BinaryDigitsWithSeparators BinaryDigit
    BinaryDigitsWithSeparators _ BinaryDigit

OctalDigitsWithSeparators ::
    OctalDigit
    _ OctalDigit
    OctalDigitsWithSeparators OctalDigit
    OctalDigitsWithSeparators _ OctalDigit

HexDigitsWithSeparators ::
    HexDigit
    _ HexDigit
    HexDigitsWithSeparators HexDigit
    HexDigitsWithSeparators _ HexDigit

FloatLiteral ::
    DecimalDigitsWithSeparators . DecimalDigitsWithSeparators ExponentPartopt
    DecimalDigitsWithSeparators ExponentPart
    HexFloatLiteral

ExponentPart ::
    ExponentIndicator SignedInteger

ExponentIndicator :: one of
    e E

HexFloatLiteral ::
    0x HexDigitsWithSeparators BinaryExponentPart
    0X HexDigitsWithSeparators BinaryExponentPart
    0x HexDigitsWithSeparators . HexDigitsWithSeparatorsopt BinaryExponentPart
    0X HexDigitsWithSeparators . HexDigitsWithSeparatorsopt BinaryExponentPart

BinaryExponentPart ::
    p SignedInteger
    P SignedInteger

SignedInteger ::
    DecimalDigitsWithSeparators
    + DecimalDigitsWithSeparators
    - DecimalDigitsWithSeparators


```

⊢ `_` is a digit separator with no value. It may not lead or trail a digit run
and may not be doubled.
⊢ There is no literal syntax for a negative number. `-1000` is unary minus
(A.4.4) applied to `1000`, folded at compile time.
⊢ A hexadecimal float requires its binary exponent; `0xC.3` alone is not a
literal.
⊢ An integer literal is untyped until it reaches a typed position, where it
takes that position’s type. A literal that does not fit the destination type is
a compile error, never a silent truncation.

#### A.1.5.2 String and character literals

```
StringLiteral ::
    " DoubleStringCharactersopt "
    ` RawStringCharactersopt `

DoubleStringCharacter ::
    SourceCharacter but not one of " or \ or LineTerminator
    \ EscapeSequence

RawStringCharacter ::
    SourceCharacter but not `

CharLiteral ::
    ' SingleCharacter '

SingleCharacter ::
    SourceCharacter but not one of ' or \ or LineTerminator
    \ EscapeSequence

EscapeSequence ::
    SingleEscapeCharacter
    HexEscapeSequence
    UnicodeEscapeSequence

SingleEscapeCharacter :: one of
    ' " \ n r t v b f 0

HexEscapeSequence ::
    x HexDigit HexDigit

UnicodeEscapeSequence ::
    u{ HexDigits }


```

⊢ A backtick string is raw and multi-line: no escape sequence is recognised
inside it, and every `LineTerminator` it spans is part of its value.
⊢ A `CharLiteral` denotes exactly one Unicode scalar value, held in 4 bytes.
`'A'` and `"A"` are different types and never interconvert implicitly.
⊢ A `StringLiteral`’s value is UTF-8 bytes with a length, and carries **no NUL
terminator**. A terminator is manufactured only where a `string` is marshalled
across an abstract-interface boundary (A.8.5).

### A.1.6 Punctuators

```
Punctuator :: one of
    (   )   [   ]   {   }   ,   .   ..  ...  :   ->
    =   +=  -=  *=  /=  %=
    +   -   *   /   %   ~   &   |   ^   <<  >>
    &+  &-  &*
    ==  !=  <   >   <=  >=  === !==
    &&  ||  !


```

⊢ The longest matching punctuator wins. `&&` is never two `&`; `..` is never two
`.`; `===` is never `==` followed by `=`.
⊢ `~` is bitwise-NOT in an expression (A.4.4) and underlying-type in a type-set
element (A.7.3). The two never collide, because a type-set element is not an
expression position.
⊢ `&` is address-of, dereference, and bitwise-AND, distinguished by arity and by
operand type (A.4.4). This is the only symbol in the language whose meaning is
resolved by the operand rather than by position.

---

## A.2 Source File

```
SourceFile :
    PackageClause BuildClauseopt ImportDeclarationsopt TopLevelDeclarationsopt

TopLevelDeclarations :
    TopLevelDeclaration
    TopLevelDeclarations TopLevelDeclaration

TopLevelDeclaration :
    FunctionDeclaration
    InitializerDeclaration
    DeinitializerDeclaration
    StructDeclaration
    ClassDeclaration
    EnumDeclaration
    TypeAliasDeclaration
    ConstraintDeclaration
    DeclareDeclaration
    VariableDeclaration


```

⊢ `PackageClause` is mandatory and must be the first non-comment token sequence
in the file.
⊢ Top-level declarations are order-independent: a declaration may refer to any
other declaration in the same package regardless of textual position. There is
no forward-declaration form because none is needed.
⊢ A `VariableDeclaration` at top level must have a compile-time-evaluable
initializer; there is no static initialization order and no initialization-time
code.

### A.2.1 Package clause

```
PackageClause :
    package Identifier


```

### A.2.2 Build clause

```
BuildClause :
    build BuildTag

BuildTag :: one of
    linux   windows darwin  js      wasm    test


```

⊢ The build tag selects the target platform and, with it, the base ABI family
used by every `declare` block in the file (A.8.2). It is not a preprocessor
directive: a file whose tag does not match the current target is excluded from
the build whole, never partially.
⊢ `build test` additionally licenses the `test` function marker (A.12.1) and
`Expected(...)` result types. It is the only build tag that changes what is
grammatical rather than only what is linkable.
⊢ Implementations may recognise additional target tags. An unrecognised tag is a
compile error, not a silently-excluded file.

### A.2.3 Import declarations

```
ImportDeclarations :
    ImportDeclaration
    ImportDeclarations ImportDeclaration

ImportDeclaration :
    import ImportPath
    import ( ImportPathList )

ImportPathList :
    ImportPath
    ImportPathList ImportPath

ImportPath :
    StringLiteral


```

⊢ The imported package’s declared name (its `PackageClause`) is the qualifier
under which its symbols are reached; the import path is a locator, not a name.
⊢ There is no aliasing form, no dot-import, and no blank import.

---

## A.3 Types

```
Type :
    TypeName
    QualifiedTypeName
    OwnershipQualifiedType
    ArrayType
    SliceType
    MapType
    TupleType
    UnitType
    FunctionType
    ChannelType
    PointerType
    [+Npu] TensorType
    InstantiatedType

TypeName :
    Identifier
    PredeclaredTypeName

QualifiedTypeName :
    Identifier . Identifier


```

### A.3.1 Scalar and inline types

`PredeclaredTypeName` (A.1.4) covers the thin scalar set. Every one of them has
a statically known width, copies by register move, and has a zero value that is
all-zero bytes. There is no boxed form of any of them and no dynamic type
information anywhere in the language, which is why every cast (A.4.4) resolves
at compile time.

```
ArrayType :
    [ ArrayLength ] Type

ArrayLength :
    IntegerLiteral
    Identifier

SliceType :
    [ ] Type

MapType :
    map [ Type ] Type


```

⊢ `ArrayLength` must be a compile-time constant. `[N]T` is inline storage of
`N × sizeof(T)` bytes with no header and no pointer; it lives wherever its
binding lives.
⊢ `[]T` is a three-word `{ptr, len, cap}` header over an implicitly
heap-allocated block — the sole implicit-allocation exception in the language,
justified by the impossibility of fitting a growable buffer into a fixed frame.
⊢ `map[K]V` requires `K` to satisfy `comparable` (A.7.4).

```
TupleType :
    ( TupleElementList )

TupleElementList :
    TupleElement
    TupleElementList , TupleElement

TupleElement :
    Type
    Identifier : Type

UnitType :
    ( )


```

⊢ Parentheses in a `TupleType` are part of the type’s shape and are never
optional. Bare comma lists appear only where a tuple is being *pulled apart* — a
destructuring `let`, or a `return` handing several values back (A.5.3, A.5.8).
⊢ A one-element tuple type requires the trailing comma in its literal form
(A.4.7) but not in its type form; a parenthesized single type is that type.
⊢ `()` is the unit type: zero bytes, one value, used where a fallible function
has nothing to hand back but an error string.

### A.3.2 Ownership-qualified types

```
OwnershipQualifiedType :
    mut Type
    var Type
    unique Type
    shared Type
    weak Type


```

⊢ `mut T` is legal only in a parameter or receiver position. It denotes
exclusive, non-owning, mutating access, and lowers to a pointer to the caller’s
slot — which is why its argument must be an addressable `var` binding or field
path.
⊢ `var T` is legal only in a parameter or receiver position. It denotes the
owning convention; whether the callee receives the caller’s original or a fresh
deep copy is decided at the call site by the presence or absence of the `var`
marker (A.4.6), never by the declaration.
⊢ `unique T`, `shared T`, and `weak T` are ordinary one-word value types and may
appear anywhere a `Type` may, including as type arguments.
⊢ `weak T` observes only a `shared` allocation. There is no `unique T` → `weak T`
path, because a `unique` block carries no control word for a weak reference to
inspect.
⊢ Qualifiers do not stack: `mut var T`, `mut mut T`, and `shared unique T` are
compile errors. `mut shared T` and `var shared T` are legal — the qualifier
applies to the handle, which is itself an ordinary value.

### A.3.3 Handle and pointer types

```
PointerType :
    typed_ptr Type
    typed_ptr ( PointerType )

AbstractType :
    abstract


```

⊢ `typed_ptr T` is the raw, last-resort pointer: no ownership tracking, no
refcount, no teardown ever emitted for a binding of this type. It is the one
type in the language where exclusivity is a convention rather than a proof.
⊢ Nesting requires parentheses: `typed_ptr (typed_ptr int32)`.
⊢ `abstract` appears only on the right-hand side of a `TypeAliasDeclaration`
(A.6.6), never inline in a signature. Each such alias is a distinct **nominal**
type; two abstract aliases never unify however identically they were minted.
⊢ An `abstract` handle has a zeroed representation, legal **only** as the value
half of an error-path tuple paired with a non-empty error string. It has no
`nil` and never participates in a null comparison.

### A.3.4 Function types

```
FunctionType :
    func ( TypeListopt ) ReturnTypeopt

TypeList :
    Type
    TypeList , Type

ReturnType :
    -> Type
    -> ExpectedType


```

⊢ A `FunctionType` names parameter *types* only; parameter names belong to
declarations, not to types.
⊢ Omitting `-> Type` is the void form. There is no `void` type name.
⊢ `ExpectedType` is valid only as the return type of a test function (A.12.2).
⊢ A non-capturing function value is one word — a bare code pointer. A capturing
closure is two words, `{code, env}`. Only the one-word form crosses an abstract
interface boundary (A.8.6), for the arithmetic reason that a foreign callback
slot holds one word and nothing foreign will own `env`.

### A.3.5 Channel and tensor types

```
ChannelType :
    chan Type

TensorType :
    tensor [ Type , ShapeList ]

ShapeList :
    IntegerLiteral
    ShapeList , IntegerLiteral


```

⊢ `chan T` is an implicitly heap-resident refcounted handle. Copying the handle
bumps the count; it is never a deep copy of buffered contents.
⊢ `TensorType` is grammatical **only** under `[+Npu]` (A.11.2). Its shape entries
are compile-time integer literals in the same bracketed list as the element type.
⊢ Signature-eligible tensor element types are `float32` and `int8`. `bf16`,
`fp8e4m3`, `fp8e5m2`, and `int4` are body-only: they may appear on a local
binding inside an `npu` body but never on the function’s own signature.

### A.3.6 Instantiated types

```
InstantiatedType :
    TypeName TypeArguments
    QualifiedTypeName TypeArguments

TypeArguments :
    [ TypeArgumentList ]

TypeArgumentList :
    Type
    TypeArgumentList , Type


```

⊢ `Stack[int32]` (instantiation) and `a[i]` (index) share bracket syntax and are
distinguished by whether the operand names a generic declaration. This is the
one syntactic overlap resolved by the operand’s meaning rather than by shape.
⊢ Bracketed type arguments are also the language’s general compile-time
configuration slot: `chan[float32]()`, `[N]T`, `new[T](n)`, and a `declare`
variant tag (A.8.2) all reuse it, so a reader encountering brackets after a name
always reads “configured at compile time”.

---

## A.4 Expressions

```
Expression[?Await, ?Lit] :
    LogicalORExpression

ExpressionList :
    Expression
    ExpressionList , Expression


```

### A.4.1 Primary expressions

```
PrimaryExpression[?Await, ?Lit] :
    Identifier
    PredeclaredTypeName
    NamespaceExpression
    Literal
    ( Expression[+Lit] )
    TupleLiteral
    ArrayLiteral
    [+Lit] CompositeLiteral
    [+Lit] MapLiteral
    EnumShorthand
    FunctionExpression
    SelectorlessBuiltinCall

NamespaceExpression :: one of
    async   gpu     npu     chan

FunctionExpression :
    func ( ParameterListopt ) FunctionMarkeropt ReturnTypeopt Block

EnumShorthand :
    . Identifier
    . Identifier ( ExpressionListopt )


```

⊢ A parenthesized expression re-enters `[+Lit]`: parentheses are the escape
hatch that lets a composite literal appear in a control-flow header.
⊢ `FunctionExpression` captures by value at creation. Assigning to a captured
binding inside the body is a compile error — the write would land on a private
copy, and the language declines to compile the lie. Writeback is spelled by
taking a `mut` parameter and letting the caller thread the pointer.
⊢ `EnumShorthand` is legal only where the enum type is inferable from context: a
typed binding, an argument position, a `return`, or a `case` label.

### A.4.2 Prefix launch and await expressions

```
LaunchExpression[?Await] :
    thread CallExpression
    async [lookahead ≠ .] CallExpression
    gpu LaunchConfigopt [lookahead ≠ .] CallExpression
    npu [lookahead ≠ .] CallExpression

CallExpression[?Await, ?Lit] :
    PostfixExpression Arguments
    PostfixExpression TypeArguments Arguments

LaunchConfig :
    ( blocks : Expression , threads : Expression )

AwaitExpression :
    await UnaryExpression


```

⊢ Each launch keyword is a **call-expression prefix**, not a declaration
qualifier: it modifies how a call is scheduled, never the callee’s signature.
⊢ The `[lookahead ≠ .]` restriction is what keeps `async.Readable(fd)`,
`gpu.…`, and `npu.Dot(a, b)` readable as namespace member access rather than as
a launch of a member call. It applies uniformly to all three device/task
prefixes so the rule is one rule and not three.
⊢ `thread` evaluates to a receive-only `chan T` carrying the callee’s single
return value. `async` used as a prefix evaluates to the same `chan T`. Because
both terminate in the identical handle, a value produced on an OS thread and
consumed by a reactor task needs no adapter.
⊢ `gpu` and `npu` launches are ordinary synchronous calls: host-typed arguments
in, a host-typed result directly out. They do not produce channels.
⊢ A `gpu`/`npu` launch is legal only when the callee carries the matching
function marker (A.6.1); a marked function is likewise not callable without its
prefix. The marker must agree at both ends.
⊢ `LaunchConfig` is legal only on `gpu`. Omitting it dispatches with a
compiler-chosen launch shape.
⊢ `await` is licensed only under `[+Await]`, which is set by an `async`-marked
function body and by `main`.
✗ `await f()` inside an unmarked function — `await` requires an enclosing
`async` function.

### A.4.3 Postfix expressions

```
PointerPrimary[?Await, ?Lit] :
    PrimaryExpression
    & PointerPrimary

PostfixExpression[?Await, ?Lit] :
    PointerPrimary
    LaunchExpression
    CallExpression
    PostfixExpression . Identifier
    PostfixExpression . DecimalDigit
    PostfixExpression [ Expression[+Lit] ]

Arguments :
    ( ArgumentListopt )

ArgumentList :
    Argument
    ArgumentList , Argument

Argument :
    OwningExpression[+Own]
    Identifier : OwningExpression[+Own]


```

⊢ `&` binds **tighter** than member access. `&p.add(1)` therefore parses as
`(&p).add(1)`; write `&(p.add(1))` when a dereferenced read of a computed
address is what is meant. This is deliberate: the parenthesis is the visible
mark that an address was computed before it was read.
⊢ `.DecimalDigit` is positional tuple access. Chains compose: `t.0.0`.
⊢ Named and positional arguments may not be mixed in one call. Named arguments
resolve to positional order at compile time and leave no trace in the binary.
⊢ `PostfixExpression [ Expression ]` forms a slice when passed a range. The
result is a two-word `{ptr, len}` view that owns nothing; while it is live, the
buffer it points into may be neither mutated nor transferred.
⊢ Interior pointers into a `[]T` do not exist, because `push` may reallocate.
Only lifetime-checked slice views do.

### A.4.4 Unary and cast expressions

```
UnaryExpression[?Await, ?Lit] :
    PostfixExpression
    [+Await] AwaitExpression
    - UnaryExpression
    ! UnaryExpression
    ~ UnaryExpression

CastExpression[?Await, ?Lit] :
    UnaryExpression
    CastExpression as Type


```

⊢ Unary `&` is **address-of** on an ordinary value and **dereference** on a
`typed_ptr T`. The direction keys on the operand’s *statically written* type, so
the meaning of a source line never flips between instantiations of a generic:
inside a generic body, `&x` where `x : T` is always address-of, even when
`T = typed_ptr U`.
⊢ Taking the address *of* a `typed_ptr` binding is therefore unspellable with
`&`, and is the sole purpose of the `addr` builtin (A.4.8).
⊢ `as` binds tighter than every binary operator, so
`count as float64 / total as float64` divides two converted values. It is
left-associative: `value as int32 as int64` is two conversions.
⊢ `as` never touches memory. Between pointer types it is a static
reinterpretation and always legal; between numeric types it is a width-selected
truncate/extend/int↔float instruction; on an enum it is a tag read. There is no
dynamic cast, because there is no runtime type information for one to consult.
⊢ `abstract` → `typed_ptr T` is legal only for a handle minted by a memory-flat
import family (C, WASM). It is a compile error for an object-graph family
(Objective-C, JS), whose handles have no byte representation to point at.
⊢ There is no `typed_ptr T` → `abstract` cast in any direction or family.
Abstract handles are minted at the foreign boundary and nowhere else.

### A.4.5 Binary operator cascade

```
ShiftExpression :
    CastExpression
    ShiftExpression << CastExpression
    ShiftExpression >> CastExpression

MultiplicativeExpression :
    ShiftExpression
    MultiplicativeExpression MultiplicativeOperator ShiftExpression

MultiplicativeOperator :: one of
    *   /   %   &   &*

AdditiveExpression :
    MultiplicativeExpression
    AdditiveExpression AdditiveOperator MultiplicativeExpression

AdditiveOperator :: one of
    +   -   |   ^   &+  &-

RangeExpression :
    AdditiveExpression .. AdditiveExpression

RelationalExpression :
    AdditiveExpression
    RangeExpression
    RelationalExpression RelationalOperator AdditiveExpression
    RelationalExpression RelationalOperator RangeExpression

RelationalOperator :: one of
    ==  !=  <   >   <=  >=  === !==

LogicalANDExpression :
    RelationalExpression
    LogicalANDExpression && RelationalExpression

LogicalORExpression :
    LogicalANDExpression
    LogicalORExpression || LogicalANDExpression


```

⊢ The shift operators sit at the **top** of the cascade, above multiplication.
This is a deliberate departure from C: a shift is a scaling operation and reads
as one, and the C precedence is the single most common source of
parenthesis-omission bugs in bit-manipulation code.
⊢ `..` is non-associative. `a..b..c` is a compile error.
⊢ Every range is half-open. There is no inclusive form; to cover the full domain
of a narrow integer type, iterate a wider one and convert.
⊢ `&+`, `&-`, `&*` are the wrapping forms. The plain forms trap on overflow.
⊢ `===` and `!==` compare storage identity and are legal on classes only. They
answer “same allocation?”, never “same bytes?” — that is `==`’s question.
⊢ `&&` and `||` short-circuit; their operands must be `bool`. There is no
truthiness conversion anywhere in the language.

### A.4.6 The ownership marker

```
OwningExpression[?Own] :
    [+Own] var TransferTarget
    Expression

TransferTarget :
    Identifier
    TransferTarget . Identifier


```

⊢ `var` prefixed to a binding in an owning position means **move**: the source
dies at that point and the destination becomes sole owner. Its omission in the
same position means **copy**: the compiler synthesizes a deep copy and the
source stays alive. One marker, two meanings, read by presence.
⊢ There is no `.clone()` and no copy operator. Copying is what happens when you
do not write `var`.
⊢ The marker takes a binding or a field path and nothing else. It does not
compose through arbitrary expressions.
⊢ The marker is meaningless on a freshly constructed value: a temporary has no
prior binding to preserve, so it is simply consumed into its destination.
⊢ `mut` is unrelated to this rule. `mut` never takes ownership, so the
copy/transfer question never arises for it and its call sites are always bare.
✗ `var w` as a statement — transfer outside an owning position.
✗ `if var w { }` — a control-flow header is not an owning position.
✗ `let y = var pick(a, b)` — transfer requires a binding or field path.

### A.4.7 Composite, array, tuple, and map literals

```
CompositeLiteral :
    TypeName LiteralBody
    InstantiatedType LiteralBody

LiteralBody :
    { FieldValueListopt }

FieldValueList :
    FieldValue
    FieldValueList , FieldValue
    FieldValueList ,

FieldValue :
    Identifier : OwningExpression[+Own]

ArrayLiteral :
    [ ElementListopt ]

ElementList :
    OwningExpression[+Own]
    ElementList , OwningExpression[+Own]
    ElementList ,

TupleLiteral :
    ( OwningExpression[+Own] , )
    ( OwningExpression[+Own] , TupleElementValueList )

TupleElementValueList :
    TupleElementValue
    TupleElementValueList , TupleElementValue

TupleElementValue :
    OwningExpression[+Own]
    Identifier : OwningExpression[+Own]

MapLiteral :
    { KeyValueListopt }

KeyValueList :
    KeyValue
    KeyValueList , KeyValue
    KeyValueList ,

KeyValue :
    Expression : OwningExpression[+Own]


```

⊢ `CompositeLiteral` and `MapLiteral` are grammatical only under `[+Lit]`, which
every expression position sets except a control-flow header — the header of `if`,
`while`, `for`, `switch`, and each `select` case clears it. Wrap the literal in
parentheses to use one there.
⊢ A one-element tuple literal requires its trailing comma; `(1)` is a
parenthesized integer.
⊢ Struct and class values differ in their construction syntax and this is not
incidental: a `struct` is built with a brace literal, a `class` is built by
calling its `init` with named arguments (A.6.4). The reader can tell which
storage discipline is in play from the punctuation alone.
⊢ Every element of an array, tuple, map, or composite literal is an owning
position (A.9.1), so `var` is legal in each.

### A.4.8 Builtin call forms

Builtins are ordinary call syntax over reserved names (A.1.4). They are listed
here because their type-argument and arity shapes are grammatical.

```
SelectorlessBuiltinCall :
    sizeof ( Type )
    alignof ( Type )
    reinterpret ( Type , Expression )
    addr ( Expression )
    new TypeArgumentsopt ( AllocArgumentList )
    delete ( Expression )
    resize ( Expression , Expression )
    resize ( Expression , Expression , zero : Expression )
    copy ( Expression , Expression , Expression )
    zero ( Expression , Expression )
    unique ( OwningExpression )
    shared ( OwningExpression )
    weak ( Expression )
    upgrade ( Expression )
    drop ( Expression )

AllocArgumentList :
    Expression
    Expression , align : Expression
    Expression , zero : Expression
    Expression , align : Expression , zero : Expression


```

⊢ `new[T]` allocates `count × sizeof(T)` bytes and returns `(typed_ptr T, string)`.
The block is **zeroed by default**; `zero: false` opts out and is a *claim* that
every byte is written before it is read. Nothing checks the claim.
⊢ `align` must be a power of two. A violation is an allocation failure — `nil`
and a non-empty string — not a distinct diagnostic.
⊢ A `count` whose byte extent overflows `uint64` is likewise an allocation
failure. This is the one place the size is computed under the language’s
control, which is why it gets a failure channel rather than undefined behavior.
⊢ `resize` on success invalidates its input pointer; on failure it leaves the
input untouched and valid. This is the sole failure path in the language that
does not zero what it was handed, because the boundary-tuple zero-value rule
applies to a *return*, not to an argument.
⊢ `copy` is always overlap-safe. There is deliberately no overlap-unsafe
variant: a split between the two would be a footgun rather than a feature.
⊢ `addr` accepts a `typed_ptr` operand only, and only an addressable one — a
`var` binding or a field path. On any other type `&x` is already the address,
and `addr(x)` is a compile error carrying a fix-it to `&`.
⊢ `unique(...)` and `shared(...)` are the only two heap doors. Each *constructs*
a wrapper around a value, so the copy/transfer rule does not apply to its
operand: the operand is moved in unconditionally, exactly as into any
constructor.
⊢ `upgrade(w)` returns `(shared T, string)` — the boundary-tuple convention
applied to a race the type system cannot statically win.
⊢ `T` in `new` may be written explicitly or inferred from the declared type of
the binding the result flows into.
⊢ `reinterpret` is a bit-cast between value types of identical byte size, unlike `as`
which performs value conversions or pointer casts. `reinterpret` never casts pointers.
⊢ `drop(x)` explicitly ends the lifetime of a transferred binding without emitting
its teardown.

---

## A.5 Statements

```
Statement[?Await, ?Npu] :
    Block
    VariableDeclaration
    AssignmentStatement
    ExpressionStatement
    IfStatement
    SwitchStatement
    WhileStatement
    ForStatement
    SelectStatement
    ReturnStatement
    DeferStatement
    BreakStatement
    ContinueStatement
    FallthroughStatement

Block :
    { StatementListopt }

StatementList :
    Statement
    StatementList Statement


```

### A.5.1 Variable declarations

```
VariableDeclaration :
    let BindingList = InitializerList
    var BindingList = InitializerList
    var Binding

Binding :
    Identifier TypeAnnotationopt
    BlankIdentifier

BindingList :
    Binding
    BindingList , Binding

TypeAnnotation :
    : Type

InitializerList :
    OwningExpression[+Own]
    InitializerList , OwningExpression[+Own]


```

⊢ `let` and `var` are statements about the **binding**, never about heap versus
stack. `let` is immutable and not guaranteed to be addressable — it may be a
register, an SSA value, or folded away entirely. `var` is mutable and owns a
real stack slot for its whole lifetime.
⊢ Because `mut` parameters are pointers, only a `var` binding may be passed to
one. A `let` may not physically exist anywhere to point at.
⊢ `var Binding` without an initializer is legal and yields the type’s zero value;
it requires a `TypeAnnotation`, since there is nothing to infer from.
⊢ A multi-binding `let`/`var` with a single initializer is a tuple destructure;
with a matching count of initializers it is parallel declaration.
⊢ Both are illegal at `[+Npu]` where the declared type is not a `tensor`,
scalar `bool`, scalar `int32`, or scalar `float32` (A.11.2).

### A.5.2 Assignment

```
AssignmentStatement :
    AssignTargetList = InitializerList
    AssignTarget CompoundAssignOperator Expression

AssignTarget :
    PostfixExpression
    & UnaryExpression
    BlankIdentifier

AssignTargetList :
    AssignTarget
    AssignTargetList , AssignTarget

CompoundAssignOperator :: one of
    +=  -=  *=  /=  %=  &=  |=  ^=  <<= >>=


```

⊢ `&p = 99` is dereference-on-the-write-side: it writes through `p`.
⊢ Assigning `nil` into a map subscript is the erase operation. This is the
load-bearing appearance of `nil` outside `typed_ptr`: `nil` is not a general
value and has no type of its own.
⊢ Assignment is a statement, never an expression. There is no assignment inside
a condition, and therefore no `=` / `==` confusion class.

### A.5.3 Return

```
ReturnStatement :
    return
    return OwningExpressionList[+Own]

OwningExpressionList :
    OwningExpression
    OwningExpressionList , OwningExpression


```

⊢ A multi-value return is written **bare**, as a comma-separated list with no
wrapping parentheses. Parentheses construct a tuple; bare commas unbuild one.
The signature’s `-> (A, B)` is a type annotation, where parentheses are the
type’s shape and are required.
⊢ Every returned expression is an owning position, so `var` is legal on each.
⊢ On an error path the value half must be the type’s zero value, never a
partially constructed value. This is a convention the compiler does not enforce,
matching the error model’s explicit-over-automatic philosophy.

### A.5.4 If

```
IfStatement[?Await] :
    if Expression[~Lit] Block
    if Expression[~Lit] Block else Block
    if Expression[~Lit] Block else IfStatement


```

⊢ The condition must be `bool`. The header is `[~Lit]`; parenthesize a composite
literal used there.
⊢ There is no initializer clause in the header. The error-checking idiom is two
statements — a destructuring `let`, then a plain `if` on the string — and its
verbosity is intentional: every branch stays visible in the text and does not
compress as call depth grows.

### A.5.5 While

```
WhileStatement[?Await] :
    while Expression[~Lit] Block


```

⊢ `while` is the only loop primitive. Stepping, reversal, and
loop-until-exhausted are all written as `while` bodies; there are no range
methods and no do/while form.
⊢ Under `[+Npu]`, loop-carried bindings must retain identical type, shape, and
element type on every iteration, and `break`/`continue` are compile errors
(A.11.2).

### A.5.6 For-in

```
ForStatement[?Await] :
    for IterationBinding in Expression[~Lit] Block

IterationBinding :
    IterationName
    IterationName , IterationName
    mut IterationName
    var IterationName

IterationName :
    Identifier
    BlankIdentifier


```

⊢ `for` has exactly one shape and consumes an iterable value. Ranges, fixed
arrays, dynamic arrays, maps, and strings are the iterables.
⊢ The bare form iterates by shared access. `mut` iterates by exclusive access,
permitting in-place mutation. `var` is the **consuming** form: each element moves
out into the loop binding, and the container is dead after the loop.
⊢ The consuming marker sits on the binding, not on the iterable. This is
deliberate — what is being transferred is each element, one per iteration, and
the marker names what moves.
⊢ The two-name form binds index-and-value over arrays and key-and-value over
maps. Map iteration order is unspecified and may differ between runs.
⊢ String iteration decodes UTF-8 into `char` scalars at variable stride;
byte-level iteration is a separate method call on the string and strides raw
`uint8`. Neither allocates.

### A.5.7 Switch

```
SwitchStatement[?Await] :
    switch Expression[~Lit] { CaseClauseListopt }

CaseClauseList :
    CaseClause
    CaseClauseList CaseClause

CaseClause :
    case PatternList : StatementListopt
    default : StatementListopt

PatternList :
    Pattern
    PatternList , Pattern

Pattern :
    Expression[~Lit]
    EnumPattern

EnumPattern :
    . Identifier
    . Identifier ( PayloadBindingList )

PayloadBindingList :
    PayloadBinding
    PayloadBindingList , PayloadBinding

PayloadBinding :
    Identifier
    BlankIdentifier

FallthroughStatement :
    fallthrough


```

⊢ Cases do not fall through implicitly; `fallthrough` is explicit and must be the
last statement in its clause.
⊢ At most one `default` clause per `switch`.
⊢ An `EnumPattern` payload binding is a **view** into the payload, not a copy.
Its arity must match the variant’s declared arity exactly; `_` discards a
position without naming it.
⊢ A `switch` over a unit-only enum with no `default` must be exhaustive.
⊢ `switch` reads the discriminant once. Dense tags lower to a jump table, sparse
ones to a compare chain.
⊢ Under `[+Npu]` the selector must be scalar; there is no per-element branching.

### A.5.8 Defer

```
DeferStatement :
    defer PostfixExpression Arguments


```

⊢ `defer` takes a call and nothing else. Its arguments are evaluated at
registration; only the call itself is postponed.
⊢ Deferred calls are collected per scope and emitted in reverse registration
order on **every** exit edge — fall-through, `return`, `break`, `continue`.
Because there is no unwinder, “every exit edge” is a finite, statically known
set, and a `defer` costs exactly the call it defers.

### A.5.9 Break, continue, expression statements

```
BreakStatement :
    break

ContinueStatement :
    continue

ExpressionStatement[?Await] :
    Expression[+Lit] but not one of CompositeLiteral or MapLiteral


```

⊢ There are no loop labels. A multi-level exit is written with an explicit flag
or an extracted function.

---

## A.6 Declarations

### A.6.1 Functions

```
FunctionDeclaration :
    func Receiveropt Identifier TypeParameterListopt ( ParameterListopt )
        FunctionMarkeropt ReturnTypeopt Block

Receiver :
    ( Identifier : ReceiverType )

ReceiverType :
    TypeName TypeParameterListopt
    mut TypeName TypeParameterListopt
    var TypeName TypeParameterListopt
    shared TypeName TypeParameterListopt

FunctionMarker :: one of
    async   gpu     npu     test

ParameterList :
    Parameter
    ParameterList , Parameter

Parameter :
    Identifier : Type
    Identifier : ... Type


```

⊢ A function carries **at most one** `FunctionMarker`. The markers name
mutually exclusive execution substrates — a reactor state machine, a device
kernel, a test entry point — and no combination of two is meaningful.
⊢ `async` on the signature declares that the function returns a state machine
rather than blocking, and sets `[+Await]` in its body.
⊢ `gpu` compiles the body to a device target instead of host machine code; the
body is otherwise unrestricted Vertex.
⊢ `npu` sets `[+Npu]`, which licenses `tensor` types and the `npu.` namespace and
simultaneously restricts the body (A.11.2). Neither the types nor the namespace
exists anywhere else.
⊢ `test` is legal only under `build test` and requires an `Expected(...)` result
type or none at all (A.12).
⊢ A function named `main` must take no parameters, return nothing, and acts as
the program entry point.
⊢ A variadic parameter must be last, and there may be at most one. It lowers to a
stack-local fixed array plus a two-word view over it.
⊢ Only the receiver position may carry `shared`; it is the spelling for a method
that needs a strong handle to itself in order to hand out weak back-references.
⊢ A receiver typed `var` consumes its receiver **unconditionally**: the receiver
position has no argument slot to carry a `var` marker, so there is no bare form
that copies. Copy first into a fresh binding to call one non-destructively. This
is the single exception to the bare-means-copy rule.

### A.6.2 Structs

```
StructDeclaration :
    struct Identifier TypeParameterListopt { FieldListopt }

FieldList :
    Field
    FieldList , Field
    FieldList ,

Field :
    Identifier : Type
    Identifier : Type = Expression


```

⊢ Fields are separated by commas. A `LineTerminator` between them is
conventional but not required.
⊢ A `struct` is inline data with no identity: fields laid out in declaration
order with ABI padding, no header, copied by value.
⊢ A field default is evaluated at construction for any field the literal omits.

### A.6.3 Classes

```
ClassDeclaration :
    class Identifier TypeParameterListopt { FieldListopt }


```

⊢ A `class` is **byte-for-byte identical in layout to a `struct**`. It differs in
its member and method model — initializers, teardown, receiver conventions,
identity comparison — not in where its bytes live. Declaring something a `class`
does not, by itself, put it on the heap.
⊢ There is no inheritance, no vtable, no dynamic dispatch, and therefore no
class header of any kind. Every call is direct.
⊢ Class methods are declared outside the class body, as `FunctionDeclaration`s
with a receiver (A.6.1). The body holds fields only.

### A.6.4 Initializers and teardown

```
InitializerDeclaration :
    func ( Identifier : ReceiverType ) init ( ParameterListopt ) Block

DeinitializerDeclaration :
    func ( Identifier : ReceiverType ) deinit ( ) Block


```

⊢ A class is constructed by calling its type name with the initializer’s
arguments — `Animal(name: "Rex")` — never with a brace literal.
⊢ `deinit` takes no parameters and returns nothing. It is emitted where the
binding’s liveness ends: fields in reverse declaration order, locals in reverse
declaration order.
⊢ A **transferred** binding simply has its teardown not emitted. No flag is set
and none is checked, which is exactly why conditional transfer is a compile
error: the moment “was it transferred?” becomes a runtime question, the language
would need drop flags, so it forbids the question instead.

### A.6.5 Enums

```
EnumDeclaration :
    enum Identifier TypeParameterListopt DiscriminantTypeopt
        { VariantListopt }

DiscriminantType :
    : PredeclaredTypeName

VariantList :
    Variant
    VariantList , Variant
    VariantList ,

Variant :
    Identifier
    Identifier ( TypeList )
    Identifier = Expression


```

⊢ A unit-only enum **is** its discriminant integer. `Status.Active as int32` is a
reinterpretation, not a conversion, and explicit discriminants merely pin the
values.
⊢ A payload enum is a tagged union sized to the largest variant plus the tag.
⊢ `= Expression` (an explicit discriminant) is legal only on a unit variant, and
only when a `DiscriminantType` was declared. Unassigned variants continue from
the previous value.
⊢ A copy of an enum value is a shallow tag-plus-payload copy unless the live
variant embeds an owning fat type, in which case the copy recurses into that
variant only — the tag tells the copy routine which interpretation to walk.

### A.6.6 Type aliases

```
TypeAliasDeclaration :
    type Identifier TypeParameterListopt = AliasTarget

AliasTarget :
    Type
    AbstractType


```

⊢ An alias to a `Type` is transparent: it names the same type and satisfies a
`~T` type-set element (A.7.3).
⊢ An alias to `abstract` is **nominal** and opaque: it declares a foreign handle
whose interior belongs to the foreign environment and is invisible to the type
system. Two abstract aliases never unify, however identical their provenance.
⊢ Copy does not exist for an `abstract` handle. It may be accessed or moved. It
is not a `unique T` and must not be spelled as one.
✗ `type SDL_Window = ref` — bare `ref` is not a type; the diagnostic suggests
`abstract`.

---

## A.7 Generics

### A.7.1 Type parameter lists

```
TypeParameterList :
    [ TypeParameterGroupList ]

TypeParameterGroupList :
    TypeParameterGroup
    TypeParameterGroupList , TypeParameterGroup

TypeParameterGroup :
    TypeParameterName
    TypeParameterName : ConstraintExpression

TypeParameterName :
    Identifier
    BlankIdentifier


```

⊢ A constraint written after a name applies to that name and to every
immediately preceding unconstrained name in the same list — `[A, B: Number]`
constrains both.
⊢ A bare name is constraint `any`: `[T]` means `[T: any]`.
⊢ A type parameter’s scope begins after its own name and runs to the end of the
declaration’s body, so a later parameter may be constrained by an earlier one.
⊢ Names must be unique within a list.
⊢ Under `any`, only assignment, argument passing, and the ownership operations
are available on a value of that type. No comparison, no arithmetic, no field
access.

### A.7.2 Constraint declarations

```
ConstraintDeclaration :
    constraint Identifier { ConstraintElementList }

ConstraintElementList :
    ConstraintElement
    ConstraintElementList ConstraintElement

ConstraintElement :
    TypeSet
    MethodRequirement
    ConstraintName

ConstraintName :
    Identifier
    QualifiedTypeName

MethodRequirement :
    func Identifier ( ParameterListopt ) ReturnTypeopt


```

⊢ Vertex has no interfaces. A constraint is its own declaration form: a
compile-time **type set**, optionally paired with required methods. It is never a
value type and is legal only in a `[...]` position.
⊢ Multiple elements in a constraint body form an **intersection**: a type
argument must satisfy all of them.
⊢ A bare `ConstraintName` element embeds that constraint’s set.
⊢ A `MethodRequirement` is satisfied by any type declaring a matching receiver
method. Because every instantiation is monomorphized, the call in the generic
body lowers to a direct call on the concrete type. This is not an interface
value and introduces no vtable.
⊢ A single identifier in a constraint body parses as both a `TypeSet` of one term
and a `ConstraintName`; it is resolved by what the name denotes.
✗ `var c: Ordered` — a constraint is not a type.

### A.7.3 Type sets

```
TypeSet :
    TypeSetTerm
    TypeSet | TypeSetTerm

TypeSetTerm :
    Type
    ~ Type


```

⊢ `|` is union: the type set is every listed type.
⊢ `~T` admits `T` and every type whose underlying type is `T`, so an alias to
`float32` still satisfies `~float32`. A bare `T` admits only `T` exactly.
⊢ `~` here is underlying-type, never bitwise-NOT. The two never collide, because
a type-set element is not an expression position.
✗ `type X = ~int` — `~T` is valid only inside a type set.

### A.7.4 Predeclared constraints

| Constraint | Admits |
| --- | --- |
| `any` | every type (the default when `:` is omitted) |
| `comparable` | every type supporting `==` / `!=` |

⊢ A `map[K]V` key parameter requires `comparable`. Under `any`, `==` on a value
of that type is a compile error.

### A.7.5 Instantiation and inference

```
InstantiationExpression :
    PostfixExpression TypeArguments Arguments


```

⊢ Type arguments may be omitted when every type parameter is determined by a
value argument. Inference reaches through composite arguments: a `[]T` argument
fixes `T`, a `~[]E` constraint fixes `E`.
⊢ Inference either succeeds or fails; on failure the compiler asks for explicit
arguments rather than guessing.
⊢ A type parameter appearing only in the return type cannot be inferred and must
be supplied explicitly.
⊢ Constraint satisfaction is checked once per instantiation, at the instantiation
site, never at runtime.

### A.7.6 Methods on generic types

⊢ A method receiver re-declares the type’s parameter list to bring the names into
scope. The receiver’s `[T]` **binds** the name; it does not introduce a fresh one.
⊢ A method may **not** declare a type parameter of its own. Everything a method
is generic over comes from its receiver type.
⊢ A constraint declared on the type is in force inside every method of that type.
⊢ Recursive instantiation must terminate. Unbounded deepening is a compile
error, because the stamping-out would not terminate.

---

## A.8 Abstract Interfaces

### A.8.1 The two block forms

```
DeclareDeclaration :
    declare framework StringLiteral DeclareBody
    declare module VariantTagopt StringLiteral DeclareBody

DeclareBody :
    { DeclareMemberListopt }

DeclareMemberList :
    DeclareMember
    DeclareMemberList DeclareMember

DeclareMember :
    ForeignFunctionDeclaration
    ForeignClassDeclaration


```

⊢ A `DeclareDeclaration` is legal only in a file carrying a `BuildClause`
(A.2.2). The build tag picks the ABI family; the block keyword and the member
shapes pick the convention within it.
⊢ The string names the module or framework the linker or bundler resolves. It is
never a path and never contains slashes.
⊢ A declare block is a **linkage boundary, not a namespace**: symbols declared
inside it are injected into the file’s current package.
⊢ `declare framework` names a platform-bundled, versioned library and is legal
only where the target platform has a first-class notion of one. Under a build tag
with no such concept it is a compile error.
⊢ `declare module` is the everything-else bucket: flat C libraries, C++ shared
objects, Windows DLLs, JS modules.

### A.8.2 Variant tags

```
VariantTag :
    [ StringLiteralList ]

StringLiteralList :
    StringLiteral
    StringLiteralList , StringLiteral


```

⊢ The bracket holds a fixed, **closed** set of tags — not an open attribute map.
It reuses the same bracketed compile-time-configuration slot as generic
instantiation, fixed-array length, and channel construction.
⊢ Omitting the bracket means “use the default convention for this build tag”.
The bracket exists to **narrow** a default, never to introduce a capability
unavailable without it.
⊢ Illegal or contradictory combinations are compile errors, checked against the
file’s build tag.
⊢ `declare framework` never takes a variant tag. Bundled message-passing linkage
has exactly one convention by design, and unlike a C++ ABI it does not fork by
compiler, standard library, or flag — which is precisely why it is safe to leave
silent.
✗ `declare framework["windows", "com"] "SomeLib" { }` — framework blocks take no
variant tag.

### A.8.3 Foreign members

```
ForeignFunctionDeclaration :
    func Identifier ( ParameterListopt ) ReturnTypeopt

ForeignClassDeclaration :
    class Identifier { ForeignClassMemberListopt }

ForeignClassMemberList :
    ForeignClassMember
    ForeignClassMemberList ForeignClassMember

ForeignClassMember :
    ForeignFunctionDeclaration
    ForeignInitializerDeclaration

ForeignInitializerDeclaration :
    init func ( ParameterListopt ) -> TypeName
    init func Identifier ( ParameterListopt ) -> TypeName


```

⊢ `init` is a **prefix modifier** on `func`, not a function name. The unnamed
form is what bare `Type(...)` construction resolves to; the named form is what
`Type.someName(...)` resolves to.
⊢ An initializer must return its enclosing type.
⊢ At most one unnamed initializer per foreign class.
⊢ Exactly what is written is what is linked. A declare block contains only
declarations corresponding to real entry points: no marker declarations, no
visibility modifiers, no remapping clauses, and no bodies.
⊢ `var` — and any consume or transfer marking — is **banned** from a foreign
declaration. Ownership is a fact about a wrapper’s field, decided in the wrapper,
not a decoration on an external stub.
⊢ Fields are banned. A declare block describes **call shape only**, never
foreign-side layout. This is what keeps the question “which C++ ABI, exactly?”
out of the type system and confined to the linker, where the variant tag answers
it.
✗ `private init func() -> Bad` — visibility modifiers are banned.
✗ `func SDL_Init() -> int32 { return 0 }` — declarations cannot have bodies.
✗ `class Foo { payload: string }` inside a declare block — fields describe layout.

### A.8.4 The boundary tuple

⊢ Foreign functions do not throw into Vertex. A foreign call that can fail — a
nullable pointer return, a JS call that may throw or yield `undefined` — is
declared as returning the standard error tuple `-> (T, string)`.
⊢ A status-plus-out-param foreign shape is declared `-> (int32, T, string)`.
⊢ On success the handle is valid and the string is empty. On failure the handle
is zeroed and the string carries a message. This is the same tuple shape as any
native fallible function: interop adopts the native convention, not the reverse.

### A.8.5 Non-resource pointer shapes

| Foreign shape | Vertex form |
| --- | --- |
| `const char*` | `string` — marshalled NUL-terminated at the boundary |
| writable scalar out-param | `mut T` — literally the pointer parameter |
| pointer plus length | `[]T` for read, `mut []T` for write |
| pointer held and strided manually | `typed_ptr T` — the last resort |
| property read or foreign static field | ordinary bodyless `func` returning the field’s type |

⊢ If a foreign signature requires a non-opaque, layout-dependent foreign type to
cross directly, that is out of scope for this layer. Wrap it behind an opaque
handle and expose accessors.

### A.8.6 Callbacks

⊢ A boundary `func(...)` parameter is a bare function pointer: one word, no
environment.
⊢ Only a **non-capturing** function converts across the boundary. A capturing
closure is rejected at compile time, and the rejection is arithmetic rather than
stylistic: the closure is two words, the foreign slot holds one, and nothing on
the foreign side will own the environment.

---

## A.9 Ownership Positions

### A.9.1 Owning positions — where `Own` is set

`Own` is set in exactly these positions, and nowhere else:

* the right-hand side of a `VariableDeclaration` or `AssignmentStatement`;
* an argument mapped to a parameter grammatically via `[+Own]`;
* an element of a tuple, array, map, or composite literal;
* a returned expression;
* the binding of a consuming `for` loop.

⊢ An argument to a parameter that is not `var`-typed must not be marked `var`.
⊢ Anywhere else, a `var` prefix is a compile error naming the position.
⊢ `Own` does not propagate into subexpressions. It is re-established at each
listed position and cleared inside any nested expression that is not itself one.

### A.9.2 Liveness

⊢ Liveness is tracked statically through control flow. Use after transfer is a
compile error, and so is use after a transfer that *may* have happened on some
path — a conditional transfer is rejected outright rather than resolved at
runtime.
⊢ A transfer inside a loop body is a compile error for the same reason: the
second iteration would consume an already-dead binding.
⊢ A single call may neither consume the same binding twice nor read it while
consuming it. Evaluation order would otherwise decide liveness, and evaluation
order is not something a reader should have to know.

### A.9.3 Exclusivity

⊢ The Law of Exclusivity — aliasing **or** mutation, never both — is enforced at
every call site by reading the callee’s signature. Dropping a call-site keyword
weakens human readability at the call site, not enforcement.
⊢ Passing one binding as two exclusive arguments is a compile error, as is
reading a binding in the same call that exclusively accesses it.
⊢ Overlap through a field path is caught identically: a method whose receiver is
a field of the value passed exclusively is rejected.
⊢ A live slice view counts as a shared borrow of the buffer it points into, so
the buffer may be neither mutated nor transferred while the view lives.
⊢ `typed_ptr T` is the one type where exclusivity is a convention rather than a
proof. Nothing about it is checked.

### A.9.4 Cost

```
copy   (bare)   :  header + payload   O(data)
transfer (var)  :  header only        O(1)

```

⊢ A bare copy of an owning fat type duplicates header *and* payload. A transfer
copies the header and stops. A non-owning view copies its two words and nothing
else.
⊢ `unique T` is one word but its bare copy is **deep** — it walks and duplicates
the pointee. This is the language’s one cost cliff hidden behind a thin type, and
it is why the marker is visible rather than inferred.
⊢ `shared T` is always cheap: copying the handle is an atomic increment,
regardless of marker.
⊢ `string` is immutable, so an implementation may share or intern payloads —
observably identical to a deep copy. This license does not extend to `[]T`,
which is mutable and must genuinely duplicate.

---

## A.10 Concurrency

### A.10.1 Channels

⊢ `chan T` is the single currency for moving values between execution contexts.
Both spawn sigils reduce to it, which is why a value produced on an OS thread and
consumed by a reactor task needs no adapter.
⊢ Construction is generic instantiation with an optional capacity:
`chan[float32]()` is an unbuffered rendezvous, `chan[int32](64)` is buffered.
⊢ Allocation failure panics rather than returning a boundary tuple, matching
native array allocation.

| Method | Waits? | Result |
| --- | --- | --- |
| `.send(v)` | yes | `void` |
| `.receive()` | yes | `T` |
| `.trySend(v)` | no | `bool` |
| `.tryReceive()` | no | `(T, string)` |
| `.close()` | no | `void` |

⊢ `.receive()` is the one method whose waiting mechanism is not fixed. Called
bare, it blocks the calling OS thread. Called as `await ch.receive()` inside an
`async` function, it suspends the task on the reactor. There is no third form and
no per-call-site ambiguity: the mode is fully determined by whether `await` is
written, which is itself legal only inside an `async` function.
⊢ A bare `.receive()` inside an `async` body blocks the underlying OS thread and
starves the reactor. It is rejected.

### A.10.2 Select

```
SelectStatement[?Await] :
    select { SelectClauseListopt }

SelectClauseList :
    SelectClause
    SelectClauseList SelectClause

SelectClause :
    case ChannelCase : StatementListopt
    default : StatementListopt

ChannelCase[?Await] :
    ChannelOperation
    AssignTargetList = ChannelOperation

ChannelOperation[?Await] :
    PostfixExpression . receive ( )
    PostfixExpression . tryReceive ( )
    [+Await] await PostfixExpression . receive ( )
    [+Await] await PostfixExpression . tryReceive ( )


```

⊢ Every case must be a channel receive operation. No other expression is legal in
case position — not a bare async call, not an arbitrary function, nothing else.
To race a standalone async call, spawn it with the `async` prefix first, which
hands back a `chan T`, and put the receive on that.
⊢ `select` introduces **no waiting behavior of its own**. Each case waits exactly
the way its receive would wait in that context.
⊢ A single `select` must be entirely bare or entirely `await`-prefixed. One mode
blocks a thread and the other suspends a task; there is no “first ready wins”
across two different wait primitives.
⊢ An optional `default` makes the whole statement non-blocking, identically in
both modes. At most one per statement.

### A.10.3 Threads and tasks

⊢ `thread` runs a call on a real OS thread. The callee is an ordinary function:
nothing about a declaration changes because some call site spawns it.
⊢ `async` marks a function whose body contains a real poll point — a place the
kernel may answer “not yet”. A call that cannot be delayed by the kernel should
not be marked, however slow it is.
⊢ Putting a blocking call inside an `async` body blocks the underlying OS thread
and starves the event loop. The language does not detect this; the marker
discipline is what makes it visible in the source.
⊢ Function coloring is accepted deliberately. Keeping the state machine explicit
is what allows a custom reactor to be written against platform primitives and
what keeps foreign blocking calls from silently breaking a hidden scheduler.

---

## A.11 Device Offload

### A.11.1 The two models

`gpu` and `npu` are device-offload markers built into the core language. They
differ by **programming model**, not by vendor. No vendor name appears anywhere
in Vertex source; the specific device is selected by the toolchain.

|  | `gpu` | `npu` |
| --- | --- | --- |
| Model | per-thread execution over an index space | whole-array operations over tensors |
| Launch shape | optional `(blocks:, threads:)` | none — shape is carried by the types |
| Body language | unrestricted Vertex | restricted (A.11.2) |
| Element access | ordinary subscripting | elementwise operators and namespace calls only |
| Divergent branching | permitted | rejected — the selector must be scalar |

⊢ `npu` names a hardware **class**, exactly as `gpu` does. A marker sitting at
the vendor level would force source targeting one vendor’s silicon to be written
using another vendor’s product name, which is why no such spelling exists.

### A.11.2 The restricted body

Under `[+Npu]`:

⊢ `tensor[...]` types and the `npu.` namespace become grammatical, and are
grammatical nowhere else.
⊢ Subscripting a tensor is a compile error. Element access is available only
through elementwise operators and namespace calls.
⊢ Elementwise `+ - * /` and unary `-` require operands sharing element type and
shape. Comparisons yield a `bool` tensor of the same shape.
⊢ A branch selector must be scalar `bool` or `int32`. Per-element branching is
expressed with the selection builtin instead.
⊢ Loop-carried bindings must keep identical type, shape, and element type across
iterations; `break` and `continue` are compile errors.
⊢ Plain casts saturate on overflow into the narrow integer types.

### A.11.3 The `npu.` namespace

⊢ The member set is **closed**. Its members are not declarable, shadowable, or
extensible, and the namespace is reachable only under `[+Npu]`.

| Category | Members |
| --- | --- |
| Math | `Abs Sign Floor Ceil Round Sqrt Rsqrt Exp Expm1 Log Log1p Sin Cos Tan Tanh Sigmoid IsFinite Max Min Mod Pow Atan2` |
| Contraction | `Dot` — accumulates in `float32` regardless of input precision |
| Selection | `Select` |
| Shape | `Reshape Transpose Broadcast Concat Slice Reverse Pad` |
| Reduction | `Sum MaxReduce MinReduce Product` |
| Constants | `Splat Iota` |
| Quantization | `Quantize Dequantize` |

⊢ `npu.Quantize[T]` and `npu.Dequantize[T]` take a type argument and a scalar
scale, and are the only members that do.

### A.11.4 Why markers rather than call-site sigils alone

⊢ A signature marker makes device targeting **static**: the compiler can reject a
construct that does not lower to the target at the definition site, before any
launch is ever written.
⊢ It prevents accidental host/device mismatch in both directions, since the
marker must agree at both ends.
⊢ It gives the restricted types somewhere to live, so `tensor`’s restrictions are
grammar rather than prose.

---

## A.12 Testing

### A.12.1 The `test` marker

⊢ `test` is a `FunctionMarker` (A.6.1), legal only under `build test`.
⊢ A `test` function takes no parameters.
⊢ Its result type is an `ExpectedType` or absent. A `test` function with no
result type passes if it compiles and runs without crashing.

### A.12.2 `Expected`

```
ExpectedType :
    Expected ( TypeName , StringLiteral )
    Expected ( error )
    Expected ( error , StringLiteral )


```

⊢ The string literal is the expected **rendered** value, compared against the
auto-emitted format for the named type — `%d` for the signed integers, `%u` for
the unsigned, `%f` for floats, `%s` for strings, and `%d` over `1`/`0` for
`bool`.
⊢ `Expected(error)` declares a **compile-failure** test: the body is expected not
to compile. Its two-argument form additionally requires the diagnostic text to
match, which is how the language pins its own error messages as part of its
specification rather than as an implementation detail.

---

## A.13 Operator Precedence Summary

Highest binding first. Every level except `..` is left-associative.

| Level | Operators |
| --- | --- |
| 0 | `&` address-of / dereference (prefix, binds tighter than `.`) |
| 1 | `.` member/tuple access, `(...)` call, `[...]` index/slice/instantiate, launch prefixes |
| 2 | `-` `!` `~` (prefix), `await` |
| 3 | `as` |
| 4 | `<<` `>>` |
| 5 | `*` `/` `%` `&` `&*` |
| 6 | `+` `-` `|` `^` `&+` `&-` |
| 7 | `..` (non-associative) |
| 8 | `==` `!=` `<` `>` `<=` `>=` `===` `!==` |
| 9 | `&&` |
| 10 | `||` |
| — | `=` `+=` `-=` `*=` `/=` `%=` `&=` `|=` `^=` `<<=` `>>=` — statements, not operators |

---

## A.14 Index of Rejected Forms

Every entry here parses and is rejected by a later phase. The list is normative:
Vertex specifies its rejections as deliberately as its acceptances, and an
implementation that accepts any of these is non-conforming.

**Ownership.** `var` outside an owning position · `var` on a computed expression
· use after transfer · use after a possibly-taken conditional transfer ·
transfer inside a loop body · a binding transferred twice in one call · a binding
read and transferred in one call · one binding passed as two exclusive arguments
· a binding read while exclusively accessed · exclusive access overlapping a
receiver’s field path · `.transfer()` in any position.

**Types.** Stacked ownership qualifiers · a constraint used as a type · `~T`
outside a type set · `mut T` outside a parameter or receiver · a `mut` argument
that is not an addressable `var` · a non-`comparable` map key · an explicit
discriminant on a payload variant.

**Generics.** A duplicate type-parameter name · a method declaring its own type
parameter · an uninferable type parameter left implicit · an operator not
licensed by a parameter’s constraint · non-terminating recursive instantiation ·
a type argument outside its constraint’s set where only `~` would admit it.

**Variables & Statements.** Assignment to a captured binding · fallthrough not
as the last statement in its clause · multiple default clauses in a switch ·
a non-exhaustive switch on a unit enum · `a..b..c`.

**Functions & Calls.** A mix of named and positional arguments.

**Pointers.** `addr` on a non-`typed_ptr` · `addr` on a computed temporary ·
ordering a pointer against `nil` · adding two pointers · an object-graph
`abstract` cast to `typed_ptr` · any cast to `abstract` · declaring `new`,
`addr`, or another reserved builtin as a member.

**Interop.** A declare block in a file with no build tag · `declare framework`
under a platform with no bundle concept · a variant tag on `declare framework` ·
a variant tag contradicting the file’s build tag · a body on a foreign
declaration · a field in a foreign class · a visibility modifier on a foreign
member · a duplicate unnamed initializer · an initializer not returning its
enclosing type · `var` on a foreign parameter · a capturing closure crossing the
boundary.

**Concurrency and devices.** A non-channel expression in `select` case position ·
bare and awaited cases mixed in one `select` · more than one `default` · `await`
outside an `async` body or `main` · a bare `.receive()` inside an `async` body ·
a launch prefix whose callee lacks the matching marker · a marked function called
without its prefix · more than one function marker · `LaunchConfig` on `npu` ·
`tensor` outside an `npu` body · subscripting a tensor · a non-scalar branch
selector under `npu` · `break`/`continue` inside an `npu` loop · a shadowed or
extended `npu.` member.

**Undefined rather than rejected.** These are *not* compile errors, and the
distinction is the whole tradeoff of reaching for the raw tier: out-of-bounds
pointer arithmetic beyond one-past-the-end · dereferencing an out-of-bounds
pointer · subtracting or ordering pointers into unrelated blocks · deleting a
non-`new` address, a stale pointer, or an offset one · reading an unzeroed block
before writing it · a bulk `copy`/`zero` past either block’s extent · a
non-power-of-two alignment · using a `typed_ptr` after a successful `resize`.

---

## A.15 What the Grammar Guarantees

Every construction in this annex serves one invariant: **every value has a
statically known layout, and every cost is decided at compile time.** The
negative space is the specification.

| Absent from every Vertex binary | Replaced by |
| --- | --- |
| Garbage collector | static liveness and scope teardown; refcounts only where `shared` is written |
| Exception unwinder | the `(T, string)` tuple and ordinary control flow |
| Vtables and dynamic dispatch | no inheritance; every call direct; generics monomorphized |
| Drop flags | conditional transfer is a compile error |
| Null-pointer discipline | no general `nil`; absence is an error tuple |
| Runtime type information | every cast resolved statically |
| Hidden allocation | the heap is reachable only through `unique`, `shared`, and the container exception — all spelled in source |

Each row is the same trade in the same direction: a runtime question converted
into a compile-time proof or a visible piece of syntax. This annex is where the
syntax is enumerated; the proof obligations it discharges are what the rest of
the specification argues for.