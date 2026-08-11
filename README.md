# vertex_grammar.md

Vertex (fork of TypeScript 7.0, stable features only) expressed in JLS §2.4 notation — the BNF variant the Java Language Specification uses for its context-free grammars. JSX is out of scope and, unlike the base file, is out of scope permanently: no `.tsx`-equivalent goal exists.

This file is `typescript_grammar.md` with every edit in `vertex_fork_ts_diff.md` applied in place. It supersedes both for questions of derivability. Where applying an edit forced a second edit the diff did not enumerate, the production is written here and the change is listed in *Appendix A*. Where a base production survived only because nothing removed it, and nothing in the corpus exercises it, it is listed in *Appendix B* rather than silently kept or silently dropped.

## Notation

```
Nonterminal:
    alternative one
    alternative two
```

- **CamelCase** words are nonterminals. Everything else — lowercase keywords, punctuation, operators — is a terminal, to appear exactly as written.
- `{x}` — zero or more occurrences of `x`.
- `[x]` — zero or one occurrence of `x`.
- `(one of)` — each symbol on the following lines is a separate alternative.
- `but not` — excludes the named expansions.
- A phrase in *(italics-by-parenthesis)* defines a nonterminal narratively where enumeration is impractical.
- A long right-hand side continues on an indented following line.

**There is no *(no LineTerminator here)* annotation in this grammar.** Every restricted production of the base file is subsumed by the `Terminator` rule of §1.8; see that section for why each one still holds.

## Deviations and parsing notes

**The `>` character is never merged with a following `>`.** Inherited unchanged, and load-bearing in a language where `block<span<int32>>` and `alignof<mutable_ptr<Sample001>>()` are ordinary.

- `>>`, `>>>`, `>>=`, and `>>>=` are **not** tokens and appear nowhere as single terminals.
- `>=` *is* still a token, with one contextual suppression: when the parser resumes the scanner at a `>` that would close a `TypeArguments` or `TypeParameters` list, maximal munch is suppressed for that `>`, and it is emitted alone even when `=` follows. `let x: Foo<Bar<T>>= y` therefore lexes `>` `>` `=`.
- Compound shift forms are written as adjacent tokens: `> >`, `> > >`, `> >=`, `> > >=`. Adjacency is required.

**`..` versus `.` versus `...`.** Maximal munch separates the three. The collision that matters is not with the member-access dot but with the numeric literal: under the base grammar `0..10` lexes as the two literals `0.` and `.10`, because `DecimalLiteral` admits a trailing dot with no fractional digits. The fractional digits are therefore made mandatory (§1.6.1), which makes `0..10` lex as `0` `..` `10` and costs the spelling `1.` — already absent from `numerics.md`, which writes `0.0`. The alternative — a scanner rule refusing to end a numeric literal on `.` when another `.` follows — was rejected as a second resumed-scanner mechanism for one literal form.

**Division versus regular expression.** One goal symbol, decided by the preceding token: after a token that can end an expression (identifier, literal, `)`, `]`, `++`, `--`, `this`, etc.) a `/` begins division; otherwise it begins a `RegularExpressionLiteral`. Note this predicate and §1.8's rule 1 are near-identical lists and are maintained together.

**`?.` lookahead.** The characters `?.` form the optional-chaining token only when not immediately followed by a decimal digit.

**Parenthesized expression versus arrow parameters versus tuple.** `( … )` at expression start is scanned as a cover. It resolves to `ArrowParameters` if `=>` follows the closer. Otherwise it is a parenthesized `Expression` — and since `Expression` is comma-separated, `(a / b, a % b)` is grammatically the comma expression and semantically a tuple construction, decided by the contextual type. Vertex adds no tuple *literal* production; the comma operator's sequencing meaning is what gives way. In declaration position the same character sequence is a `TupleBindingPattern` (§10.1), selected by the `let`/`var`/`const` head rather than by lookahead.

**Angle-bracket assertion versus generic arrow.** `<` at expression start is a cover: it resolves to the `TypeParameters` of an `ArrowFunction` when what follows the closing `>` parses as `( [ParameterList] ) [ReturnTypeAnnotation]` followed by `=>`; otherwise it is the type assertion of §9.3. `numerics.md` spells assertions with `as` throughout; the prefix form survives from the base grammar and is a candidate for removal (*Appendix B*).

**Instantiation expression versus relational chain.** After a `MemberExpression` or `CallExpression`, `< … >` is `TypeArguments` or a less-than chain according to a **predicate on the token after the candidate closing `>`**:

1. `(`, `NoSubstitutionTemplate`, or `TemplateHead` — always `TypeArguments`.
2. `<`, `>`, `+`, or `-` — never `TypeArguments`.
3. any other token — `TypeArguments` if a `LineTerminator` precedes it, **or** it is a binary or relational operator (`*` `/` `%` `**` `==` `===` `!=` `!==` `<=` `>=` `&` `|` `^` `&&` `||` `??` `instanceof` `in` `as` `satisfies`), **or** it cannot begin an expression (`)` `]` `}` `:` `;` `,` `?` `=` `.`, end of input, among others); otherwise less-than.

Case 1 carries almost the whole unmanaged tier: `make_shared<Sample001>(0, 0)`, `sizeof<Sample001>()`, `bit_cast<uint32>(x)`, `alloc_uninit<Sample001>(usize(64))`, `pointer_from_address<Sample001>(…)`, `findViewById<TextView>(id)`.

**Statement termination.** See §1.8. It replaces automatic semicolon insertion outright; nothing in this file is error-driven.

---

## §1 — Lexical Structure

### §1.1 Input

```
Input:
    [HashbangComment] {InputElement}

InputElement:
    WhiteSpace
    LineTerminator
    Comment
    Token

HashbangComment:
    # ! {InputCharacter}

InputCharacter:
    (any Unicode code point, but not LineTerminator)

LineTerminator:
    (LF, CR, LS (U+2028), or PS (U+2029); CR LF is one LineTerminator)

WhiteSpace:
    (TAB, VT, FF, SP, NBSP, ZWNBSP, or any Unicode Zs code point)
```

A `HashbangComment` is admitted only as the very first characters of the input.

`LineTerminator` remains a distinct input element: §1.8 depends on it exactly as ASI did.

### §1.2 Comments

```
Comment:
    TraditionalComment
    EndOfLineComment

TraditionalComment:
    / * CommentTail

CommentTail:
    * CommentTailStar
    NotStar CommentTail

CommentTailStar:
    /
    * CommentTailStar
    NotStarNotSlash CommentTail

NotStar:
    InputCharacter but not *
    LineTerminator

NotStarNotSlash:
    InputCharacter but not * or /
    LineTerminator

EndOfLineComment:
    / / {InputCharacter}
```

A `TraditionalComment` containing a `LineTerminator` counts as a `LineTerminator` for §1.8.

### §1.3 Tokens

```
Token:
    IdentifierName
    PrivateIdentifier
    Keyword
    Literal
    Punctuator
```

### §1.4 Identifiers

```
IdentifierName:
    IdentifierStart {IdentifierPart}

IdentifierStart:
    (any Unicode ID_Start code point)
    $
    _
    \ UnicodeEscapeSequence

IdentifierPart:
    (any Unicode ID_Continue code point)
    $
    \ UnicodeEscapeSequence
    (ZWNJ or ZWJ)

Identifier:
    IdentifierName but not ReservedWord

PrivateIdentifier:
    # IdentifierName

BindingIdentifier:
    Identifier

TypeIdentifier:
    Identifier but not a PredefinedType name
```

The `PredefinedType` exclusion applies only where a type name is *introduced* or appears unqualified. After a `.` there is no ambiguity, so `TypeName` admits a full `IdentifierName` on the right of a dot.

`int8`…`int64`, `uint8`…`uint64`, `usize`, `float32`, `float64`, `byte` are ordinary `TypeIdentifier`s and **not** `PredefinedType` entries. This is what makes `int32(a)` parse as a `CallExpression` on an `Identifier` rather than requiring a conversion production; the whole of *Numeric Conversion Calls* in `numerics.md` is bought by leaving these names alone.

### §1.5 Keywords

```
ReservedWord: (one of)
    break      case       catch      class      const
    continue   debugger   default    delete     do
    else       enum       export     extends    false
    finally    for        func       if         import
    in         instanceof new        null       return
    struct     super      switch     this       throw
    true       try        typeof     var        void
    while      with

ContextuallyReservedWord: (one of)
    await      yield      let        static
    implements interface  package    private    protected
    public
```

`function` is gone from the reserved set; `func` and `struct` replace and extend it. All input is strict, so no `ContextuallyReservedWord` is available as a binding name; the distinction remains semantic.

```
ContextualKeyword: (one of)
    abstract   accessor   any        as         asserts
    async      bigint     bool       boolean    constructor
    declare    destructor get        global
    graph      infer      int        intrinsic  is
    kernel     keyof      meta       mutating   namespace
    never      number     object     out        override
    readonly   satisfies  set        string     symbol
    target     type       undefined  unique     unknown
    use        using
```

A contextual keyword is recognized only when it appears as a terminal in the production that admits it; everywhere else it is an ordinary `Identifier`. This is what `types.md` relies on when it says `var mutating = 0` remains a legal binding, and it extends unchanged to `use`, `kernel`, `graph`, and `destructor`.

Removed from the base set: `of`, `from`, `require`, `defer` — each was a terminal only of a production deleted in §4.1 or §8.

Four entries in the list above are terminals of no surviving production and are kept only because nothing removed them: `number` and `boolean` (displaced from `PredefinedType` by `int` and `bool`), and `using` (its declaration form and both for-of heads are gone). They behave as ordinary identifiers. See *Appendix A*.

### §1.6 Literals

```
Literal:
    NullLiteral
    BooleanLiteral
    NumericLiteral
    StringLiteral
    RegularExpressionLiteral

NullLiteral:
    null

BooleanLiteral: (one of)
    true false
```

#### §1.6.1 Numeric literals

```
NumericLiteral:
    DecimalLiteral
    DecimalBigIntegerLiteral
    NonDecimalIntegerLiteral
    NonDecimalIntegerLiteral BigIntSuffix

DecimalBigIntegerLiteral:
    0 BigIntSuffix
    NonZeroDigit [DecimalDigits] BigIntSuffix
    NonZeroDigit NumericLiteralSeparator DecimalDigits BigIntSuffix

BigIntSuffix:
    n

DecimalLiteral:
    DecimalIntegerLiteral . DecimalDigits [ExponentPart]
    . DecimalDigits [ExponentPart]
    DecimalIntegerLiteral [ExponentPart]

DecimalIntegerLiteral:
    0
    NonZeroDigit [DecimalDigits]
    NonZeroDigit NumericLiteralSeparator DecimalDigits

DecimalDigits:
    DecimalDigit
    DecimalDigits DecimalDigit
    DecimalDigits NumericLiteralSeparator DecimalDigit

NumericLiteralSeparator:
    _

DecimalDigit: (one of)
    0 1 2 3 4 5 6 7 8 9

NonZeroDigit: (one of)
    1 2 3 4 5 6 7 8 9

ExponentPart:
    ExponentIndicator [Sign] DecimalDigits

ExponentIndicator: (one of)
    e E

Sign: (one of)
    + -

NonDecimalIntegerLiteral:
    BinaryIntegerLiteral
    OctalIntegerLiteral
    HexIntegerLiteral

BinaryIntegerLiteral:
    0 b BinaryDigits
    0 B BinaryDigits

BinaryDigits:
    BinaryDigit
    BinaryDigits BinaryDigit
    BinaryDigits NumericLiteralSeparator BinaryDigit

BinaryDigit: (one of)
    0 1

OctalIntegerLiteral:
    0 o OctalDigits
    0 O OctalDigits

OctalDigits:
    OctalDigit
    OctalDigits OctalDigit
    OctalDigits NumericLiteralSeparator OctalDigit

OctalDigit: (one of)
    0 1 2 3 4 5 6 7

HexIntegerLiteral:
    0 x HexDigits
    0 X HexDigits

HexDigits:
    HexDigit
    HexDigits HexDigit
    HexDigits NumericLiteralSeparator HexDigit

HexDigit: (one of)
    0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F
```

**The first `DecimalLiteral` alternative requires fractional digits.** `1.` is not a literal; `1.0` is. This is the `..` collision fix from *Deviations* and the only lexical edit the range operator costs. `0x7f0b_0001`, `3_000_000_000`, and `0xffffffff` are unaffected — separators and hex forms are inherited intact.

The separator is never trailing. The `BigIntSuffix` attaches to decimal and non-decimal numerals but never to a fractional or exponent form. Legacy octal is excluded. The token after a `NumericLiteral` may not begin with an `IdentifierStart` or `DecimalDigit`.

#### §1.6.2 String literals

```
StringLiteral:
    " {DoubleStringCharacter} "
    ' {SingleStringCharacter} '

DoubleStringCharacter:
    InputCharacter but not " or \
    \ EscapeSequence
    LineContinuation

SingleStringCharacter:
    InputCharacter but not ' or \
    \ EscapeSequence
    LineContinuation

LineContinuation:
    \ LineTerminator

EscapeSequence:
    CharacterEscapeSequence
    0 (not followed by DecimalDigit)
    HexEscapeSequence
    UnicodeEscapeSequence

CharacterEscapeSequence:
    SingleEscapeCharacter
    NonEscapeCharacter

SingleEscapeCharacter: (one of)
    ' " \ b f n r t v

NonEscapeCharacter:
    InputCharacter but not EscapeCharacter or LineTerminator

EscapeCharacter:
    SingleEscapeCharacter
    DecimalDigit
    x
    u

HexEscapeSequence:
    x HexDigit HexDigit

UnicodeEscapeSequence:
    u HexDigit HexDigit HexDigit HexDigit
    u { CodePoint }

CodePoint:
    (HexDigits whose value is ≤ 0x10FFFF)
```

The `StringLiteral` carries more weight in Vertex than in the base language: module specifiers and their scheme prefixes (`"dynamic:libc"`, `"objc:WebKit"`, `"jvm:java.util"`), selector and descriptor method names (`"webView:didFinishNavigation:"`, `"setText(I)V"`), and `offsetof<T>("x")` field names are all ordinary string literals. None of them is a grammar production, which is why every scheme document reports a grammar cost of zero.

#### §1.6.3 Template literal tokens

```
NoSubstitutionTemplate:
    ` {TemplateCharacter} `

TemplateHead:
    ` {TemplateCharacter} ${

TemplateMiddle:
    } {TemplateCharacter} ${

TemplateTail:
    } {TemplateCharacter} `

TemplateCharacter:
    $ (not followed by { )
    \ EscapeSequence
    \ NotEscapeSequence
    LineContinuation
    LineTerminator
    InputCharacter but not ` or \ or $ or LineTerminator

NotEscapeSequence:
    (a sequence after \ that forms neither an EscapeSequence nor a
     LineContinuation)
```

`TemplateMiddle` and `TemplateTail` are produced only when the scanner is resumed at the `}` closing a substitution. The `\ NotEscapeSequence` alternative exists for tagged templates only.

#### §1.6.4 Regular expression literals

```
RegularExpressionLiteral:
    / RegularExpressionBody / RegularExpressionFlags

RegularExpressionBody:
    RegularExpressionFirstChar {RegularExpressionChar}

RegularExpressionFirstChar:
    RegularExpressionNonTerminator but not * or \ or / or [
    RegularExpressionBackslashSequence
    RegularExpressionClass

RegularExpressionChar:
    RegularExpressionNonTerminator but not \ or / or [
    RegularExpressionBackslashSequence
    RegularExpressionClass

RegularExpressionBackslashSequence:
    \ RegularExpressionNonTerminator

RegularExpressionNonTerminator:
    InputCharacter

RegularExpressionClass:
    [ {RegularExpressionClassChar} ]

RegularExpressionClassChar:
    RegularExpressionNonTerminator but not ] or \
    RegularExpressionBackslashSequence

RegularExpressionFlags:
    {IdentifierPart}
```

Lexical grammar only; the pattern grammar is ECMA-262 §22.2 and is not restated. §1.8 rule 1 names `RegularExpressionLiteral` as a statement-ending token, which is the deliberate decision to keep the form rather than an accident of inheritance.

### §1.7 Punctuators

```
Punctuator: (one of)
    {    }    (    )    [    ]    .    ..   ...  ;
    ,    <    >    <=   >=   ==   !=   ===  !==  +
    -    *    /    %    **   ++   --   <<   &    |
    ^    !    ~    &&   ||   ??   ?    :    ?.   =
    +=   -=   *=   /=   %=   **=  <<=  &=   |=   ^=
    &&=  ||=  ??=  =>   @
```

`..` is new. `>>`, `>>>`, `>>=`, and `>>>=` remain absent by design. `#` appears only inside `PrivateIdentifier` and `HashbangComment`.

### §1.8 Statement termination

**Replaces** automatic semicolon insertion and every restricted production of the base grammar.

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

This is rule-driven, not error-driven: a line beginning `(` or `[` cannot silently continue the previous statement, which is the failure mode ASI existed to paper over. `;` remains a legal terminal everywhere.

**Where `Terminator` is written in the productions below.** Statement and member boundaries are structural and are *not* spelled in the productions: a `Terminator` separates consecutive items in any container named by rule 2, and two statements may not be juxtaposed without one. `Terminator` appears explicitly only where its presence or absence selects between alternatives — `FunctionBodyOrTerminator`, the bare form of `AmbientModuleDeclaration`, and `AmbientFunctionDeclaration`. Every other mandatory `;` of the base grammar is simply gone from the right-hand side.

**Each replaced restricted production, and why it still holds.** `return`, `break`, `continue`, `throw`, and `yield` before their operands: all five keywords either appear in rule 1 or precede a token that does, so a line break terminates the statement. Postfix `++`/`--`: the preceding operand ends in an `Identifier`, `)`, or `]`. Before `=>`: the preceding `)` triggers insertion at statement level. After `async` and after `accessor`: both are `Identifier`s, so a line break makes them expression statements or field names respectively. Before the non-null `!`: same as postfix. The base file needed nine narrative exceptions; rule 1 needs none.

---

## §2 — Types

### §2.1 Type

```
Type:
    UnionType
    UnionType extends NonConditionalType ? Type : Type
    FunctionType
    ConstructorType

NonConditionalType:
    UnionType
    FunctionType
    ConstructorType

UnionType:
    [|] IntersectionType {| IntersectionType}

IntersectionType:
    [&] TypeOperatorType {& TypeOperatorType}
```

The check type is a `UnionType` and the `extends` operand a `NonConditionalType`, so a nested conditional must be parenthesized. Both restrictions are structural.

The union arm does the heavy lifting at every foreign boundary: `mutable_ptr<Sample002> | null`, `shared_ptr<Sample001> | null`, `span<byte> | IOException`, `block<int32> | null`. Nullability and fallibility are told, not inferred, and this is the production they are told in.

```
TypeOperatorType:
    PostfixType
    keyof TypeOperatorType
    readonly TypeOperatorType
    mutating TypeOperatorType
    unique TypeOperatorType
    infer TypeIdentifier [extends Type]

PostfixType:
    PrimaryType
    PostfixType [ Type ]
```

`mutating` is new. `readonly` is unedited as a production; only its operand set widens from array and tuple types to struct types, which is semantic. Both are legal in parameter, return, and `this`-parameter position only — also semantic, and stated in `types.md` rather than encoded here, since a passing mode is not a first-class type.

**`PostfixType [ ]` is removed.** Contiguous storage is `span<T>`, `block<T>`, and `FixedArray<T, N>`. Indexed access `PostfixType [ Type ]` is unaffected. This removal is what makes `...args: CVarArg` in `extern.md` the only spelling for a variadic extern parameter rather than a choice between two.

### §2.2 Primary types

```
PrimaryType:
    ( Type )
    ParenthesizedTupleType
    PredefinedType
    TypeReference
    ObjectType
    TupleType
    TypeQuery
    MappedType
    TemplateLiteralType
    LiteralType
    this

PredefinedType: (one of)
    any unknown never void undefined null
    bool int string symbol object bigint intrinsic

ParenthesizedTupleType:
    ( Type , TypeList [,] )

TypeList:
    Type {, Type}

TypeReference:
    TypeName [TypeArguments]

TypeQuery:
    typeof EntityName [TypeArguments]

LiteralType:
    StringLiteral
    NumericLiteral
    - NumericLiteral
    BooleanLiteral
    NullLiteral
    NoSubstitutionTemplate
```

`number` → `int` and `boolean` → `bool` are straight renames of `PredefinedType` entries; the list is otherwise untouched.

`ParenthesizedTupleType` takes ≥2 elements, keeping it disjoint from `( Type )`. Resolution order for `( … )` in type position: `=>` after the closer → `FunctionType`; a depth-0 comma → `ParenthesizedTupleType`; otherwise parenthesization. `func divide(a: int, b: int): (int, int)` takes the second arm.

`ImportType` is removed — see *Appendix A*.

```
TemplateLiteralType:
    TemplateHead Type {TemplateMiddle Type} TemplateTail
```

### §2.3 Object types and type members

```
ObjectType:
    { [TypeMemberList [TypeMemberSeparator]] }

TypeMemberList:
    TypeMember
    TypeMemberList TypeMemberSeparator TypeMember

TypeMemberSeparator: (one of)
    ; ,

TypeMember:
    PropertySignature
    CallSignature
    ConstructSignature
    IndexSignature
    MethodSignature
    GetAccessorSignature
    SetAccessorSignature

PropertySignature:
    [readonly] PropertyName [?] [TypeAnnotation]

CallSignature:
    [TypeParameters] ( [ParameterList] ) [ReturnTypeAnnotation]

ConstructSignature:
    new [TypeParameters] ( [ParameterList] ) [ReturnTypeAnnotation]

IndexSignature:
    [readonly] [ IdentifierName : Type ] TypeAnnotation

MethodSignature:
    PropertyName [?] CallSignature

GetAccessorSignature:
    get PropertyName ( ) [TypeAnnotation]

SetAccessorSignature:
    set PropertyName ( FormalParameter )

TypeAnnotation:
    : Type

ReturnTypeAnnotation:
    : Type
    : TypePredicate
```

`ObjectType` is a container for §1.8 rule 2, so `TypeMemberSeparator` is optional between members on separate lines and the `;`/`,` spellings survive for single-line object types.

`PropertyName` in `MethodSignature` reaches `ComputedPropertyName`, which is what admits `[Symbol.index](i: I): mutating T` in an `interface` without any new production.

### §2.4 Tuple types

```
TupleType:
    [ [TupleElementList [,]] ]

TupleElementList:
    TupleElement {, TupleElement}

TupleElement:
    Type
    Type ?                     but not when the element is preceded by a rest element
    ... Type
    IdentifierName [?] : Type
    ... IdentifierName : Type
```

Bracket tuple types survive the removal of postfix `[]` — that removal deletes the *array* spelling, not this one. Two spellings for a tuple now exist, `[A, B]` and `(A, B)`, and only the second appears anywhere in the corpus; see *Appendix B*.

### §2.5 Function and constructor types

```
FunctionType:
    [TypeParameters] ( [ParameterList] ) => Type
    [TypeParameters] ( [ParameterList] ) => TypePredicate

ConstructorType:
    [abstract] new [TypeParameters] ( [ParameterList] ) => Type

TypePredicate:
    Identifier is Type
    this is Type
    asserts Identifier
    asserts this
    asserts Identifier is Type
    asserts this is Type
```

`FunctionType` is the spelling for an Objective-C block and for a JVM functional interface alike: `(c: Sample003 | null, d: Sample004 | null) => void`, `() => void`. Neither target needed a production.

### §2.6 Mapped types

```
MappedType:
    { [MappedReadonly] [ TypeIdentifier in Type [as Type] ] [MappedOptional]
        [TypeAnnotation] [;] }

MappedReadonly:
    readonly
    + readonly
    - readonly

MappedOptional:
    ?
    + ?
    - ?
```

### §2.7 Type parameters and type arguments

```
TypeParameters:
    < TypeParameterList [,] >

TypeParameterList:
    TypeParameter {, TypeParameter}

TypeParameter:
    {TypeParameterModifier} TypeIdentifier [Constraint] [TypeParameterDefault]
    const BindingIdentifier TypeAnnotation

TypeParameterModifier: (one of)
    const in out

Constraint:
    extends Type

TypeParameterDefault:
    = Type

TypeArguments:
    < TypeArgumentList >

TypeArgumentList:
    Type {, Type}
```

The second `TypeParameter` alternative is the const generic parameter: `struct Sample001<T, const N: usize>`. It is distinguished from the base language's `<const T>` modifier by the presence of `:` — one token of lookahead past the identifier. The bound value is usable in value position within the body, which is semantic.

`TypeParameters` admits a trailing comma; `TypeArguments` does not. The trailing comma no longer buys generic-arrow disambiguation (no JSX goal exists) and is kept only for compatibility of shape.

---

## §3 — Names

```
EntityName:
    Identifier
    EntityName . IdentifierName

TypeName:
    TypeIdentifier
    TypeName . IdentifierName

NamespaceName:
    Identifier
    NamespaceName . Identifier

QualifiedName:
    IdentifierName
    QualifiedName . IdentifierName
```

`TypeName` is left-recursive on itself, so the `PredefinedType` exclusion binds only to the head: `Ns.int` is a derivable type name. `NamespaceName` is used only by `NamespaceHeader` (§7).

---

## §4 — Programs and Modules

**Replaces** `Script` / `Module` / `ModuleItem`. There is one goal symbol and no script-versus-module distinction — a Vertex file opens with its namespace and is a module unconditionally.

```
CompilationUnit:
    NamespaceHeader {UseDirective} {TopLevelItem}

TopLevelItem:
    ImportDeclaration
    ExportDeclaration
    StatementListItem
```

The `{UseDirective}` position is fixed by the production rather than by a directive-region rule (§13.3), which is the whole reason `use` is a keyword-led statement instead of a string literal.

### §4.1 Import declarations

**Replaces** all of the base §4.1.

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

Gone: `ImportClause`, `ImportedDefaultBinding`, `NameSpaceImport`, `NamedImports`, `ImportSpecifier`, `FromClause`, `WithClause`, `WithEntryList`, `ImportEqualsDeclaration`, the `type`-only forms, and `defer`.

The group needs no separator: after a spec's `StringLiteral` the next token is a `StringLiteral`, an `Identifier`/`_`, or `)`. Note the group is a `(` container, so §1.8 rule 2 inserts nothing inside it — the specs are delimited by their own shape, not by line breaks.

**No named-binding form exists.** This is the load-bearing absence in the language: `import` binds Vertex modules by path only, so a foreign name has nowhere to come from except a `declare module` block, which is why `objc.md`, `extern.md`, and `jvm.md` can all say the block is both the declaration and the binder without any of them adding a production to say it.

### §4.2 Export declarations

**Replaces** `ExportDeclaration`:

```
ExportDeclaration:
    export Declaration
    export BindingDeclaration
```

**Removes** `export NamedExports`, `export ExportFromClause FromClause`, `export default`, `export =`, and `NamespaceExportDeclaration` — each produces a binding only the removed import forms could consume.

---

## §5 — Declarations, Variables, and Functions

```
Declaration:
    HoistableDeclaration
    ClassDeclaration
    StructDeclaration
    BindingDeclaration
    TypeAliasDeclaration
    InterfaceDeclaration
    EnumDeclaration
    AmbientDeclaration

HoistableDeclaration:
    FunctionDeclaration
    GeneratorDeclaration
    AsyncFunctionDeclaration
    AsyncGeneratorDeclaration
```

`StructDeclaration` is added; `LexicalDeclaration` becomes `BindingDeclaration`; `NamespaceDeclaration` and `ImportEqualsDeclaration` are removed with the productions that defined them.

### §5.1 Binding declarations

**Replaces** `VariableStatement` + `LexicalDeclaration`:

```
BindingDeclaration:
    VarLetConst VariableDeclarationList

VarLetConst: (one of)
    var let const

VariableDeclarationList:
    VariableDeclaration {, VariableDeclaration}

VariableDeclaration:
    BindingIdentifier [!] [TypeAnnotation] [Initializer]
    BindingPattern [TypeAnnotation] Initializer

Initializer:
    = AssignmentExpression
```

All three heads are block-scoped. `var` and `let` differ in mutability, not scope — Swift's split, not JavaScript's — and `const` is compile-time-only, which is why three keywords survive where two would otherwise do. Neither `var` hoisting nor function scoping is inherited; both were properties of the removed `VariableStatement`.

`using` and `await using` declarations are gone with `LexicalDeclaration`. `jvm.md` wants a scope-bound resource release construct and does not get one here.

```
TypeAliasDeclaration:
    type TypeIdentifier [TypeParameters] = Type
```

### §5.2 Function declarations and parameters

**Replaces** `FunctionDeclaration` / `FunctionExpression`:

```
FunctionDeclaration:
    {Decorator} {FunctionModifier} func BindingIdentifier CallSignature
        FunctionBodyOrTerminator

FunctionModifier: (one of)
    kernel graph

GeneratorDeclaration:
    func * BindingIdentifier CallSignature FunctionBodyOrTerminator

AsyncFunctionDeclaration:
    async func BindingIdentifier CallSignature FunctionBodyOrTerminator

AsyncGeneratorDeclaration:
    async func * BindingIdentifier CallSignature FunctionBodyOrTerminator

FunctionBodyOrTerminator:
    Block
    Terminator

FunctionExpression:
    func [BindingIdentifier] CallSignature Block
    func * [BindingIdentifier] CallSignature Block
    async func [BindingIdentifier] CallSignature Block
    async func * [BindingIdentifier] CallSignature Block
```

`{Decorator}` on a function is new — `@inline123 func sample001(): void {}` — and so is `{FunctionModifier}`. The generator and async variants take the `function` → `func` swap only, and so carry neither decorators nor modifiers; the asymmetry is inherited from the diff rather than argued for, and is the one place where `kernel`/`graph` and `async` cannot combine even to be rejected semantically.

`FunctionBodyOrTerminator` replaces `FunctionBodyOrSemicolon` wherever the base file names it: `ConstructorDeclaration`, `MethodDeclaration`, and the accessors. A `Terminator` body is an overload signature.

A `kernel func` lowers to PTX or MSL and admits `device_ptr<T>` and the thread-context intrinsics in its body; a `graph func` lowers to a StableHLO string and admits neither. Both restrictions are semantic — the modifier is the only syntax the split costs.

```
ParameterList:
    ThisParameter
    ThisParameter , FormalParameterList
    FormalParameterList

ThisParameter:
    this [TypeAnnotation]

FormalParameterList:
    FormalParameter {, FormalParameter} [,]
    {FormalParameter ,} RestParameter

FormalParameter:
    {ParameterModifier} BindingIdentifier [?] [TypeAnnotation] [Initializer]
    {ParameterModifier} BindingPattern [TypeAnnotation] [Initializer]

ParameterModifier:
    Decorator
    AccessibilityModifier
    override
    readonly

AccessibilityModifier: (one of)
    public private protected

RestParameter:
    ... BindingIdentifier [TypeAnnotation]
    ... BindingPattern [TypeAnnotation]
```

`ThisParameter`'s `TypeAnnotation` is where `mutating` and `readonly` bind on a method: `sample002(this: readonly Sample001): int32`. Swift spells this on the declaration; Vertex spells it on the parameter, and the base grammar already had the position.

`ParameterModifier`s other than decorators are parameter properties and are legal only on a constructor's parameters. `types.md` makes `constructor(private x: mutating Sample001)` a semantic error on non-escaping grounds — the grammar derives it, and must, since the two features are independently inherited.

A rest parameter's annotation is the type of each argument, not of a collection: `...args: CVarArg`. Nothing else would be true at a C call boundary, and with postfix `[]` removed there is no longer a spelling that suggests otherwise.

### §5.3 Arrow functions

```
ArrowFunction:
    ArrowParameters => ConciseBody

AsyncArrowFunction:
    async ArrowParameters => ConciseBody

ArrowParameters:
    BindingIdentifier
    [TypeParameters] ( [ParameterList] ) [ReturnTypeAnnotation]

ConciseBody:
    AssignmentExpression   but not beginning with {
    Block
```

The bare-identifier form admits no type annotation. A body that is an object literal must be parenthesized. The two `(no LineTerminator here)` restrictions the base file placed around `=>` and `async` are §1.8's.

---

## §6 — Classes and Structs

```
ClassDeclaration:
    {Decorator} {ClassModifier} class BindingIdentifier [TypeParameters]
        [ClassHeritage] { ClassBody }

ClassExpression:
    {Decorator} {ClassModifier} class [BindingIdentifier] [TypeParameters]
        [ClassHeritage] { ClassBody }

ClassModifier:
    abstract

ClassHeritage:
    [ClassExtendsClause] [ImplementsClause]

ClassExtendsClause:
    extends LeftHandSideExpression [TypeArguments]

ImplementsClause:
    implements ClassTypeList

ClassTypeList:
    TypeReference {, TypeReference}
```

`ClassExtendsClause` is inherited unedited even though `types.md` states classes have no inheritance and `implements` is the sole route to polymorphism. The restriction is semantic because two targets need exemptions from it: a foreign ambient class may declare `extends` to *describe* a hierarchy that already exists in the foreign runtime (`objc.md`, `jvm.md`), and a Vertex-side class may extend a foreign one and only a foreign one (`jvm.md`, where `MainActivity extends Activity` is not deferrable). A grammar-level removal would have to be reintroduced for both.

```
ClassBody:
    {ClassElement}

ClassElement:
    ConstructorDeclaration
    DestructorDeclaration
    PropertyDeclaration
    MethodDeclaration
    AccessorFieldDeclaration
    GetAccessor
    SetAccessor
    ClassIndexSignature
    StaticBlock

ClassElementModifier: (one of)
    public protected private static abstract override
    readonly declare async

ClassElementName:
    PropertyName
    PrivateIdentifier

ConstructorDeclaration:
    {ClassElementModifier} constructor
        ( [ParameterList] ) FunctionBodyOrTerminator

DestructorDeclaration:
    destructor ( ) Block

PropertyDeclaration:
    {Decorator} {ClassElementModifier} ClassElementName [? or !]
        [TypeAnnotation] [Initializer]

MethodDeclaration:
    {Decorator} {ClassElementModifier} [*] ClassElementName [?]
        CallSignature FunctionBodyOrTerminator

AccessorFieldDeclaration:
    {Decorator} {ClassElementModifier} accessor
        ClassElementName [TypeAnnotation] [Initializer]

GetAccessor:
    {Decorator} {ClassElementModifier} get ClassElementName ( )
        [TypeAnnotation] FunctionBodyOrTerminator

SetAccessor:
    {Decorator} {ClassElementModifier} set ClassElementName
        ( FormalParameter ) FunctionBodyOrTerminator

ClassIndexSignature:
    {ClassElementModifier} IndexSignature

StaticBlock:
    static { [StatementList] }
```

`DestructorDeclaration` is new: no parameters, no modifiers, no overloads, and a mandatory `Block` — there is no signature-only form because there is nothing to overload. `destructor` is contextual, so a field or method named `destructor` remains derivable and is distinguished by what follows.

The `;` alternative of `ClassElement` is gone: an empty member is a `Terminator`, not an element.

`accessor` is a terminal of `AccessorFieldDeclaration` and not a `ClassElementModifier`; listing it in both makes `accessor x` ambiguous. The base file's restricted production after `accessor` is §1.8's — a line break there makes `accessor` an ordinary field name.

Constructors admit no decorators; their parameters may be decorated.

```
StructDeclaration:
    {Decorator} struct BindingIdentifier [TypeParameters] { {StructElement} }

StructElement:
    {Decorator} {AccessibilityModifier} [readonly] ClassElementName TypeAnnotation
    ConstructorDeclaration
    MethodDeclaration
```

A `StructElement` is a deliberate subset of `ClassElement`: no `extends`, no static blocks, no accessors, no `static`/`abstract`/`override`/`declare`, no initializer, no `?`/`!`, and a **mandatory** `TypeAnnotation` — a value type with a fixed layout has no inferred field types. `{Decorator}` on `StructElement` is what carries `@bits(3)`; `{Decorator}` on `StructDeclaration` carries `@packed` and `@align(64)`.

The layout decorators settle a spelling question rather than adding one: a `layout(...)` clause was rejected because decorators on non-class declarations are needed for function attributes and bitfields regardless, so the clause would have been a second mechanism for the same job.

```
PropertyName:
    IdentifierName
    StringLiteral
    NumericLiteral
    ComputedPropertyName

ComputedPropertyName:
    [ AssignmentExpression ]
```

The `StringLiteral` arm of `PropertyName` is what makes `"webView:didFinishNavigation:"(a: WKWebView, b: WKNavigation | null): void` a declaration and `a["sample001:sample002:"](b, c)` a call. Selector sends and JVM descriptor sends are both this arm plus §9.2's computed member call, and neither target adds a production.

---

## §7 — Interfaces, Enums, and Namespaces

```
InterfaceDeclaration:
    interface TypeIdentifier [TypeParameters] [InterfaceExtendsClause]
        ObjectType

InterfaceExtendsClause:
    extends ClassTypeList
```

An Objective-C protocol, a Java interface, and a Vertex interface are one production. Declaration merging is semantic and, in a language with no ambient `.d.ts` culture, largely vestigial.

**Replaces** `EnumDeclaration` / `EnumMember`:

```
EnumDeclaration:
    enum BindingIdentifier [TypeParameters] [TypeAnnotation] { {EnumMember} }

EnumMember:
    EnumMemberName [= AssignmentExpression]
    EnumMemberName ( ParameterList )

EnumMemberName:
    IdentifierName
    StringLiteral
```

The backing type arrives through `TypeAnnotation` — the same `:` token used everywhere else in the grammar — so `enum StatusCode: int32` needs nothing new. `TypeParameters` are new, and give `enum Option<T>` and `enum Result<T, E>`. The associated-value arm reuses `ParameterList` verbatim, so a case is spelled like a function signature: `Circle(radius: float64)`.

Members are terminator-separated rather than comma-separated, per §1.8. `[const] enum` is gone: `const` is compile-time-only and an enum is already a compile-time construct.

**Replaces** `NamespaceDeclaration`:

```
NamespaceHeader:
    namespace NamespaceName
```

**Removes** `NamespaceBody` and `NamespaceElement` entirely, along with the braced form and its internal export arms. A namespace is a file-scoped header, reachable only from `CompilationUnit` (§4) — it is not a `Declaration`, cannot nest, and cannot be re-opened. A dotted `NamespaceName` names one namespace, not a chain of implicitly-exported ones.

---

## §8 — Statements

```
Statement:
    Block
    EmptyStatement
    ExpressionStatement
    IfStatement
    BreakableStatement
    ContinueStatement
    BreakStatement
    ReturnStatement
    LabelledStatement
    ThrowStatement
    TryStatement
    DebuggerStatement

BreakableStatement:
    IterationStatement
    SwitchStatement

StatementListItem:
    Statement
    Declaration

StatementList:
    StatementListItem {StatementListItem}

Block:
    { [StatementList] }

EmptyStatement:
    ;

ExpressionStatement:
    Expression   but not beginning with { or func or async func
                 or class or struct or let [
```

`WithStatement` is removed — the base file kept it only for completeness and it was already unreachable under mandatory strict mode.

`EmptyStatement` is retained from the base grammar and is unreachable in practice: a `;` in statement position is scanned as a `Terminator` (§1.8), so the empty statement can never be selected. It is a candidate for removal (*Appendix B*).

The `ExpressionStatement` lookahead list takes the `function` → `func` swap and adds `struct`; both openers now begin `Declaration`s that `StatementListItem` selects first.

```
IfStatement:
    if ConditionExpression Block [else (Block | IfStatement)]
    if let BindingIdentifier = ConditionExpression Block [else (Block | IfStatement)]

IterationStatement:
    do Block while ConditionExpression
    while ConditionExpression Block
    for ForBinding in ConditionExpression Block

ForBinding:
    BindingIdentifier
    BindingPattern

SwitchStatement:
    switch ConditionExpression { {CaseClause} [DefaultClause] }

CaseClause:
    case AssignmentExpression {, AssignmentExpression} Block

DefaultClause:
    default Block

ConditionExpression:
    (Expression with no unparenthesized ObjectLiteral at depth 0)
```

Parens are dropped from every head and the body is a mandatory `Block`. Consequences, all deliberate:

- `if x doA()` is not derivable, and the dangling-`else` ambiguity disappears with it — the base file's nearest-unmatched-`if` rule is unnecessary here, since only an `IfStatement` may follow `else` unbraced.
- `case 0 :` and fallthrough are gone. Comma lists replace grouped fallthrough, and `default` is structurally last rather than positionally free.
- `for`-`in`, `for`-`of`, `for await`, and the C-style triple collapse into one `in` form. The iterated expression may be a `RangeExpression` (`for i in 0..10`), which is the whole reason `..` exists.
- `ForBinding` reaches `TupleBindingPattern` (§10.1), giving `for (name, score) in scores` with no destructuring-specific production.
- `ForBinding` still carries no `TypeAnnotation`.

`ConditionExpression` is the price of paren-free heads, and it is the same price Go and Rust pay. `if let` binds one identifier and no patterns; `let` is contextually reserved by position after `if`.

```
ContinueStatement:
    continue [Identifier]

BreakStatement:
    break [Identifier]

ReturnStatement:
    return [Expression]

ThrowStatement:
    throw Expression

DebuggerStatement:
    debugger

LabelledStatement:
    Identifier : Statement

TryStatement:
    try Block Catch
    try Block Finally
    try Block Catch Finally

Catch:
    catch [( CatchParameter )] Block

CatchParameter:
    BindingIdentifier [TypeAnnotation]
    BindingPattern [TypeAnnotation]

Finally:
    finally Block
```

`return`, `break`, and `continue` appear in §1.8 rule 1, so a bare `return` on its own line terminates rather than swallowing the next line's expression — the restricted production, obtained from the general rule.

`ThrowStatement` and `TryStatement` are inherited unedited and are the largest unreviewed surface in this file. `jvm.md` states flatly that the JVM unwinds and Vertex does not, spells foreign exceptions as return unions narrowed with `instanceof`, and routes unrecoverable failure through `panic`. On that reading none of these three productions has a language behind it. They are listed in *Appendix B* pending `control_flow.md`.

---

## §9 — Expressions

### §9.1 Primary expressions

```
PrimaryExpression:
    this
    Identifier
    Literal
    ArrayLiteral
    ObjectLiteral
    FunctionExpression
    ClassExpression
    TemplateLiteral
    ( Expression )

TemplateLiteral:
    NoSubstitutionTemplate
    TemplateHead Expression {TemplateMiddle Expression} TemplateTail

ArrayLiteral:
    [ [Elision] ]
    [ ElementList ]
    [ ElementList , [Elision] ]

ElementList:
    [Elision] ArrayElement { , [Elision] ArrayElement }

Elision:
    , {,}

ArrayElement:
    AssignmentExpression
    ... AssignmentExpression

ObjectLiteral:
    { [PropertyDefinitionList [,]] }

PropertyDefinitionList:
    PropertyDefinition {, PropertyDefinition}

PropertyDefinition:
    Identifier
    PropertyName : AssignmentExpression
    MethodDefinition
    ... AssignmentExpression

MethodDefinition:
    [async] [*] PropertyName CallSignature Block
    get PropertyName ( ) [TypeAnnotation] Block
    set PropertyName ( FormalParameter ) Block
```

`ObjectLiteral` earns its keep at the Objective-C boundary, where the trailing selector pieces of a labeled call land in one: `a.sample001(b, { sample002: c })`, `evaluateJavaScript("…", { completionHandler: … })`. It is also the construct `ConditionExpression` excludes at depth 0, which is why a labeled call in an `if` head needs parentheses.

`( Expression )` doubles as tuple construction — see *Deviations*.

### §9.2 Left-hand-side expressions

```
MemberExpression:
    PrimaryExpression
    MemberExpression [ Expression ]
    MemberExpression . IdentifierName
    MemberExpression . PrivateIdentifier
    MemberExpression !
    MemberExpression TemplateLiteral
    SuperProperty
    MetaProperty
    new MemberExpression [TypeArguments] Arguments

SuperProperty:
    super [ Expression ]
    super . IdentifierName

MetaProperty:
    new . target

NewExpression:
    MemberExpression
    new NewExpression

CallExpression:
    MemberExpression [TypeArguments] Arguments
    SuperCall
    CallExpression [TypeArguments] Arguments
    CallExpression [ Expression ]
    CallExpression . IdentifierName
    CallExpression . PrivateIdentifier
    CallExpression !
    CallExpression TemplateLiteral

SuperCall:
    super [TypeArguments] Arguments

Arguments:
    ( [ArgumentList [,]] )

ArgumentList:
    Argument {, Argument}

Argument:
    AssignmentExpression
    ... AssignmentExpression

InstantiationExpression:
    MemberExpression TypeArguments
    CallExpression TypeArguments

OptionalExpression:
    MemberExpression OptionalChain
    CallExpression OptionalChain
    OptionalExpression OptionalChain

OptionalChain:
    ?. [TypeArguments] Arguments
    ?. [ Expression ]
    ?. IdentifierName
    ?. PrivateIdentifier
    OptionalChain [TypeArguments] Arguments
    OptionalChain [ Expression ]
    OptionalChain . IdentifierName
    OptionalChain . PrivateIdentifier
    OptionalChain !

LeftHandSideExpression:
    NewExpression
    CallExpression
    InstantiationExpression
    OptionalExpression
```

`ImportCall` and `import . meta` are removed (*Appendix A*). The two `TemplateLiteral` alternatives inside `OptionalChain` are removed with them — they existed in the base file only to carry an unconditional early error.

This section is where most of the unmanaged tier lives without contributing a production. `a.offset(1)` and `a[0].offset(1)` are the same member-call production applied to a pointer and to its pointee. `make_shared<Sample001>(0, 0)`, `bit_cast<uint32>(x)`, `compile(sample001)`, `launch(config, a, b, c, n)`, `weak_ptr(a)`, `b.lock()`, `addressof(a)`, `construct_at(…)`, and `destroy_at(…)` are all `CallExpression`. The `[ Expression ]` arm is simultaneously unchecked pointer indexing (`a[0] = 0xFF`) and the literal-selector send (`a["sample002(Ljava/lang/String;)V"](b)`).

The postfix `!` is the non-null assertion, and its base-grammar line-break restriction is §1.8's.

### §9.3 Update, unary, and cast expressions

```
UpdateExpression:
    LeftHandSideExpression
    LeftHandSideExpression ++
    LeftHandSideExpression --
    ++ UnaryExpression
    -- UnaryExpression

UnaryExpression:
    UpdateExpression
    delete UnaryExpression
    void UnaryExpression
    typeof UnaryExpression
    + UnaryExpression
    - UnaryExpression
    ~ UnaryExpression
    ! UnaryExpression
    await UnaryExpression
    < Type > UnaryExpression
```

`< Type > UnaryExpression` is the prefix type assertion. `numerics.md` spells assertions `b as uint8` throughout and never uses this form; see *Appendix B*.

### §9.4 Exponentiation, multiplicative, additive, shift, range

```
ExponentiationExpression:
    UnaryExpression
    UpdateExpression ** ExponentiationExpression

MultiplicativeExpression:
    ExponentiationExpression
    MultiplicativeExpression * ExponentiationExpression
    MultiplicativeExpression / ExponentiationExpression
    MultiplicativeExpression % ExponentiationExpression

AdditiveExpression:
    MultiplicativeExpression
    AdditiveExpression + MultiplicativeExpression
    AdditiveExpression - MultiplicativeExpression

ShiftExpression:
    AdditiveExpression
    ShiftExpression << AdditiveExpression
    ShiftExpression > > AdditiveExpression
    ShiftExpression > > > AdditiveExpression

RangeExpression:
    ShiftExpression
    AdditiveExpression .. AdditiveExpression
```

**`RangeExpression` sits between `ShiftExpression` and `RelationalExpression`, and its placement is provisional.** The diff specifies the operands (`AdditiveExpression .. AdditiveExpression`) and defers the level; this file picks the lowest level at which `0..n + 1` still means `0..(n + 1)` while `a..b == c` remains a comparison of a range rather than a range to a comparison. The construction is non-associative by shape — `a..b..c` is underivable — which is intended: a range of ranges is not a thing.

Two collisions are already resolved elsewhere and are noted here because this is the production that provokes them: the `..`/`.`/`...` munch order (§1.7) and the trailing-dot numeric literal (§1.6.1).

### §9.5 Relational, equality, and operand operators

```
RelationalExpression:
    RangeExpression
    RelationalExpression < RangeExpression
    RelationalExpression > RangeExpression
    RelationalExpression <= RangeExpression
    RelationalExpression >= RangeExpression
    RelationalExpression instanceof RangeExpression
    RelationalExpression in RangeExpression
    PrivateIdentifier in RangeExpression
    RelationalExpression as Type
    RelationalExpression as const
    RelationalExpression satisfies Type

EqualityExpression:
    RelationalExpression
    EqualityExpression == RelationalExpression
    EqualityExpression != RelationalExpression
    EqualityExpression === RelationalExpression
    EqualityExpression !== RelationalExpression
```

`instanceof` is the narrowing form for an exception-union return at a foreign boundary, and it is deliberately not `if let`: one is a value of another type, the other is absence.

`in` is now a terminal of both this production and `IterationStatement`. The base grammar's exclusion of `in` from a classic `for` head dies with that head, and the new exclusion is the reverse one: the `in` of a `for` head is not this operator, resolved by the head's fixed shape (`for ForBinding in …`) rather than by parameterization.

`a as uint8` is a static assertion with zero representation change, distinct from the conversion call `uint8(a)`, which is a `CallExpression`. Only one of the two is derivable in this section, which is the point.

### §9.6 Binary logical, conditional, assignment, comma

```
BitwiseANDExpression:
    EqualityExpression
    BitwiseANDExpression & EqualityExpression

BitwiseXORExpression:
    BitwiseANDExpression
    BitwiseXORExpression ^ BitwiseANDExpression

BitwiseORExpression:
    BitwiseXORExpression
    BitwiseORExpression | BitwiseXORExpression

LogicalANDExpression:
    BitwiseORExpression
    LogicalANDExpression && BitwiseORExpression

LogicalORExpression:
    LogicalANDExpression
    LogicalORExpression || LogicalANDExpression

CoalesceExpression:
    CoalesceExpressionHead ?? BitwiseORExpression

CoalesceExpressionHead:
    CoalesceExpression
    BitwiseORExpression

ShortCircuitExpression:
    LogicalORExpression
    CoalesceExpression

ConditionalExpression:
    ShortCircuitExpression
    ShortCircuitExpression ? AssignmentExpression : AssignmentExpression

AssignmentExpression:
    ConditionalExpression
    YieldExpression
    ArrowFunction
    AsyncArrowFunction
    LeftHandSideExpression = AssignmentExpression
    LeftHandSideExpression AssignmentOperator AssignmentExpression
    ObjectAssignmentPattern = AssignmentExpression
    ArrayAssignmentPattern = AssignmentExpression

AssignmentOperator:
    SingleTokenAssignmentOperator
    > >=
    > > >=

SingleTokenAssignmentOperator: (one of)
    *=  /=  %=  +=  -=  <<=  &=  ^=  |=  **=  &&=  ||=  ??=

YieldExpression:
    yield
    yield AssignmentExpression
    yield * AssignmentExpression

Expression:
    AssignmentExpression
    Expression , AssignmentExpression
```

`??` may not mix unparenthesized with `&&` or `||`; the stratification encodes it. `?:` is right-associative and is the only route from a `bool` to an integer, since `numerics.md` provides no conversion call in that direction.

`Expression , AssignmentExpression` is retained, but read *Deviations*: in value position inside parentheses it is how a tuple is written, so the sequencing reading of the comma operator is no longer available uncontested.

---

## §10 — Patterns

### §10.1 Binding patterns (declaration position)

```
BindingPattern:
    ObjectBindingPattern
    ArrayBindingPattern
    TupleBindingPattern

TupleBindingPattern:
    ( BindingElement , BindingElementList [,] )

ObjectBindingPattern:
    { [BindingPropertyList [,]] }
    { [BindingPropertyList ,] BindingRestProperty }

BindingRestProperty:
    ... BindingIdentifier

BindingPropertyList:
    BindingProperty {, BindingProperty}

BindingProperty:
    BindingIdentifier [Initializer]
    PropertyName : BindingElement

BindingElement:
    BindingIdentifier [Initializer]
    BindingPattern [Initializer]

ArrayBindingPattern:
    [ [Elision] [BindingRestElement] ]
    [ BindingElementList [,] [Elision] [BindingRestElement] ]

BindingElementList:
    [Elision] BindingElement { , [Elision] BindingElement }

BindingRestElement:
    ... BindingIdentifier
    ... BindingPattern
```

`TupleBindingPattern` takes ≥2 elements, matching `ParenthesizedTupleType` (§2.2) element for element: `let (quotient, remainder) = divide(17, 5)` binds against `(int, int)`, and `for (name, score) in scores` binds against the element type of the iterated value.

`ArrayBindingPattern` survives the removal of postfix `[]` for the same reason `TupleType` does — that removal deleted a *type* production. Whether it should survive the removal of the array type it destructures is a question for the same appendix entry.

### §10.2 Assignment patterns (assignment position)

```
ObjectAssignmentPattern:
    { [AssignmentPropertyList [,]] }
    { [AssignmentPropertyList ,] ... DestructuringAssignmentTarget }

AssignmentPropertyList:
    AssignmentProperty {, AssignmentProperty}

AssignmentProperty:
    Identifier [Initializer]
    PropertyName : AssignmentElement

AssignmentElement:
    DestructuringAssignmentTarget [Initializer]

ArrayAssignmentPattern:
    [ [Elision] [AssignmentRestElement] ]
    [ AssignmentElementList [,] [Elision] [AssignmentRestElement] ]

AssignmentElementList:
    [Elision] AssignmentElement { , [Elision] AssignmentElement }

AssignmentRestElement:
    ... DestructuringAssignmentTarget

DestructuringAssignmentTarget:
    LeftHandSideExpression
```

There is no `TupleAssignmentPattern` counterpart to §10.1's addition: `(a, b) = f()` in assignment position is the parenthesized comma expression, and an assignment to it is not derivable. Whether tuple destructuring should reach assignment position as well as declaration position is open.

---

## §11 — Decorators

```
Decorator:
    @ DecoratorMemberExpression
    @ DecoratorCallExpression
    @ ( Expression )

DecoratorMemberExpression:
    Identifier
    DecoratorMemberExpression . IdentifierName

DecoratorCallExpression:
    DecoratorMemberExpression [TypeArguments] Arguments
```

`Decorator` itself is unedited. What changes is where `{Decorator}` appears: added to `FunctionDeclaration` (§5.2), `StructDeclaration` and `StructElement` (§6), alongside the inherited positions on classes, methods, fields, accessors, getters, setters, and constructor parameters.

**A decorator on its own line is not terminated away from its declaration.** §1.8 rule 1 does not list `)` reached through a `DecoratorCallExpression`'s `Arguments` — more precisely, a decorator is a declaration prefix rather than a statement, so the parser is never at a statement boundary between `@align(64)` and the `struct` that follows it. This is the one place where the terminator rule needed a carve-out and got it structurally instead.

`@packed`, `@align(64)`, `@bits(3)`, `@inline123`, `@objc`, and `@jvm` are all this production. Which member kinds a given decorator may target is semantic; that layout control is spelled as decorators at all is a settled question (§6).

---

## §12 — Ambient Declarations

```
AmbientDeclaration:
    declare AmbientVariableStatement
    declare AmbientFunctionDeclaration
    declare AmbientClassDeclaration
    declare AmbientEnumDeclaration
    declare AmbientStructDeclaration
    declare AmbientModuleDeclaration

AmbientVariableStatement:
    var AmbientBindingList
    let AmbientBindingList
    const AmbientBindingList

AmbientBindingList:
    AmbientBinding {, AmbientBinding}

AmbientBinding:
    BindingIdentifier [TypeAnnotation]

AmbientFunctionDeclaration:
    func BindingIdentifier CallSignature Terminator

AmbientEnumDeclaration:
    enum BindingIdentifier { {EnumMember} }

AmbientStructDeclaration:
    struct BindingIdentifier

AmbientModuleDeclaration:
    module StringLiteral { {ForeignModuleElement} }
    module StringLiteral Terminator

ForeignModuleElement:
    export AmbientFunctionDeclaration
    export declare AmbientClassDeclaration
    export InterfaceDeclaration
```

`declare NamespaceDeclaration` and `declare global { NamespaceBody }` are removed with `NamespaceBody` (§7); see *Appendix A*.

`AmbientStructDeclaration` is `declare struct Sample001` — a name with no body, legal only in pointer positions. That restriction is semantic; the grammar's contribution is refusing to admit a body, which is what makes "layout-free" unambiguous at the parse level.

**`ForeignModuleElement` is narrowed from the base grammar's full `NamespaceBody`.** This is the production that makes "the block is both the declaration and the binder" grammatical rather than conventional: three arms, all `export`-led, nothing else derivable inside the braces. Combined with §4.1's absence of a named-binding import form, it is structurally impossible for a foreign name to enter a file by any other route.

Scheme prefixes — `dynamic:`, `objc:`, `jvm:` — live inside the `StringLiteral` and cost zero grammar. An unknown scheme is a resolution error, not a parse error, and adding a scheme is a compiler change rather than a language change. The distinction between a link-time and a first-use binding, and between a library, a framework, and a package name, is entirely in the resolver.

```
AmbientClassDeclaration:
    [abstract] class BindingIdentifier [TypeParameters] [ClassHeritage]
        { {AmbientClassBodyElement} }

AmbientClassBodyElement:
    {ClassElementModifier} constructor ( [ParameterList] )
    {ClassElementModifier} ClassElementName [? or !] [TypeAnnotation]
    {ClassElementModifier} [*] ClassElementName [?] CallSignature
    {ClassElementModifier} accessor ClassElementName [TypeAnnotation]
    {ClassElementModifier} get ClassElementName ( ) [TypeAnnotation]
    {ClassElementModifier} set ClassElementName ( FormalParameter )
    {ClassElementModifier} IndexSignature
```

Ambient class members take the full `ClassElementModifier` set; only bodies and initializers are excluded. Member boundaries are §1.8's, so the `;` that ended each of these in the base grammar is gone from the productions.

`ClassElementName` reaches `PropertyName`'s `StringLiteral` arm, which is how an overload set is disambiguated by descriptor (`"sample002(Ljava/lang/String;)V"(a: string): void`) and how a delegate protocol's colliding selectors are declared (`"webView:didFailNavigation:withError:"(…)`). No production distinguishes a selector from a descriptor from an ordinary name — the resolver does, from the enclosing block's scheme.

There is no `AmbientDestructorDeclaration`. A foreign object's teardown belongs to the foreign runtime, and `destructor` on a Vertex-side `@objc` class is an ordinary `DestructorDeclaration` in an ordinary `ClassBody`.

---

## §13 — Directives and Comment-Position Grammar

### §13.1 Use directives

**Replaces** `DirectivePrologue`:

```
UseDirective:
    use Identifier
```

Reachable only from `CompilationUnit` (§4), which fixes the region positionally: after the namespace header, before the first `TopLevelItem`. There is no longer a longest-initial-run rule, no distinction between a directive and a string-literal expression statement, and nothing left for the base file's TS1347 to constrain — a string literal in statement position is now an ordinary expression statement everywhere.

The operand is a bare `Identifier`, so `use strict`, `use metal`, `use cuda`, `use freestanding`, `use jvm`, and `use windows123` are one production. What a directive *selects* varies sharply and none of it is grammar: `use cuda` and `use metal` are file-scoped target selections that unlock and restrict type families; `use jvm` selects nothing at all and is an assertion about a whole-program build setting that errors if the build disagrees. An unrecognized directive is a resolution error.

### §13.2 Triple-slash directives

```
TripleSlashDirective:
    / / / < reference DirectiveAttribute {DirectiveAttribute} / >

DirectiveAttribute:
    path = StringLiteral
    types = StringLiteral
    lib = StringLiteral
    resolution-mode = StringLiteral
```

Inherited unedited, and unexercised: Go-form imports resolve by path, `declare module` is the sole source of foreign names, and `resolution-mode` names a distinction (`require` versus `import`) that no longer exists. See *Appendix B*.

### §13.3 Check-control pragmas

```
CheckPragma:
    / / @ts-expect-error {InputCharacter}
    / / @ts-ignore {InputCharacter}
    / / @ts-nocheck {InputCharacter}
    / / @ts-check {InputCharacter}
```

Inherited unedited. `@ts-check` and `@ts-nocheck` are meaningful only for checked JavaScript, which has no analogue here; the `@ts-` spelling of the surviving two is a fork artifact. See *Appendix B*.

---

## Appendix A — Consequential edits

Edits this file makes that `vertex_fork_ts_diff.md` does not enumerate, each forced by an edit it does.

1. **`DecimalLiteral` requires fractional digits** (§1.6.1). Without it `0..10` lexes as `0.` `.10` and `RangeExpression` is unreachable for integer literals — the single most common range there is. Costs the spelling `1.`. The alternative (a scanner rule suppressing the trailing dot when another `.` follows) was rejected as a second resumed-scanner mechanism.

2. **`ImportType`, `ImportTypeAttributes`, `ImportCall`, and `import . meta` are removed** (§2.2, §9.2). `ImportTypeAttributes` is defined in terms of `WithEntryList`, which §4.1 explicitly deletes, so the type-position form was already dangling. The call form and `import.meta` survive that deletion grammatically but name an ES module-loading model that Go-form imports replaced wholesale.

3. **`declare global { NamespaceBody }` is removed** (§12). §7 deletes `NamespaceBody`; §12's other consumer was replaced by `ForeignModuleElement`; this arm had nothing left to derive.

4. **`Declaration` loses `NamespaceDeclaration` and `ImportEqualsDeclaration` and gains `StructDeclaration`** (§5). The first two are deleted productions; the third is added by §6 and must be reachable.

5. **`WithStatement` and the `;` arm of `ClassElement` are removed** (§8, §6). The first was already unreachable under mandatory strict mode; the second is now a `Terminator`.

6. **`RangeExpression` is placed between `ShiftExpression` and `RelationalExpression`** (§9.4). The diff specifies operands and defers the level explicitly; this is a placement, not a decision, and is marked provisional in situ.

7. **Four `ContextualKeyword` entries are orphaned** (§1.5): `number` and `boolean`, displaced from `PredefinedType`; `using`, whose declaration form died with `LexicalDeclaration` and whose for-of heads died with `for`-`of`. They are kept in the list because the diff removes exactly four entries and names them; they are terminals of nothing and should probably follow.