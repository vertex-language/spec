# typescript_grammar.md

TypeScript (7.0, stable features only) expressed in JLS §2.4 notation — the BNF variant the Java Language Specification uses for its context-free grammars, chosen for being shorter and easier to read than the ECMAScript style. JSX is out of scope.

TypeScript 6.0 and 7.0 introduced no new syntax; 6.0 *removed* several constructs, and 7.0 (the Go port) preserves 6.0's syntax and semantics exactly. This file therefore tracks 5.9's productions minus the removals, which are marked below where they applied.

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
- *(no LineTerminator here)* at a point in a production forbids a `LineTerminator` between the surrounding terminals/nonterminals at that point.
- A long right-hand side continues on an indented following line.

## Deviations and parsing notes

**The `>` character is never merged with a following `>`.** Identical to the `java_grammar.md` deviation, and adopted here for the same reason: `Map<string, Array<Array<number>>>` closes with three separate `>` tokens.

- `>>`, `>>>`, `>>=`, and `>>>=` are **not** tokens and appear nowhere as single terminals.
- `>=` *is* still a token, with one contextual suppression: when the parser resumes the scanner at a `>` that would close a `TypeArguments` or `TypeParameters` list, maximal munch is suppressed for that `>`, and it is emitted alone even when `=` follows. `let x: Foo<Bar<T>>= y;` therefore lexes `>` `>` `=` — two list closers and the `=` of an initializer. This is the same resumed-scanner mechanism used for `TemplateMiddle`/`TemplateTail` (§1.6.3) and mirrors tsc's `>`-rescanning. Everywhere else, maximal munch applies to every operator except the `>`-`>` join. `=>` is unaffected (it joins `=` with a *following* `>`, which the rule permits).
- Compound shift forms are written as adjacent tokens: `> >`, `> > >`, `> >=`, `> > >=`. Adjacency (no white space or comment between) is required for the parser to join them; `a > > b` written with a space in the source is two relational operators and a syntax error.

**Division versus regular expression.** ECMAScript resolves `/` with dual lexical goal symbols. `mocha` uses one goal and decides by the preceding token: after a token that can end an expression (identifier, literal, `)`, `]`, `++`, `--`, `this`, etc.) a `/` begins division; otherwise it begins a `RegularExpressionLiteral`.

**`?.` lookahead.** The characters `?.` form the optional-chaining token only when not immediately followed by a decimal digit; `a?.3:b` lexes `?` `.3` `:` (a conditional).

**Parenthesized expression versus arrow parameters.** `( ... )` at expression start is scanned as a cover; it is re-interpreted as `ArrowParameters` if and only if `=>` follows (with no intervening `LineTerminator`). The productions below show the two resolved forms, not the cover.

**Angle-bracket assertion versus generic arrow.** In `.ts`, `<` at expression start is likewise a cover: it resolves to the `TypeParameters` of an `ArrowFunction` when what follows the closing `>` parses as `( [ParameterList] ) [ReturnTypeAnnotation]` followed by `=>`; otherwise it is the type assertion of §9.3. `<T>(x) => x` is an arrow; `<T>(x)` alone asserts a parenthesized expression. (`.tsx` reads the same characters as JSX and admits neither form; JSX is out of scope.)

**Instantiation expression versus relational chain.** After a `MemberExpression` or `CallExpression`, `< … >` is `TypeArguments` (an instantiation expression, generic call, or tagged template) or a less-than chain according to a **predicate on the token after the candidate closing `>`** — not a closed follow set:

1. `(`, `NoSubstitutionTemplate`, or `TemplateHead` — always `TypeArguments`.
2. `<`, `>`, `+`, or `-` — never `TypeArguments`; the original `<` is the less-than operator.
3. any other token — `TypeArguments` if a `LineTerminator` precedes it, **or** it is a binary or relational operator (`*` `/` `%` `**` `==` `===` `!=` `!==` `<=` `>=` `&` `|` `^` `&&` `||` `??` `instanceof` `in` `as` `satisfies`), **or** it cannot begin an expression (`)` `]` `}` `:` `;` `,` `?` `=` `.`, end of input, among others); otherwise less-than.

Enumerations restricted to `(`/backtick, or to a punctuation-only set, are both wrong: `f<T> * x` and a line break after `f<T>` also select `TypeArguments`.

**Automatic semicolon insertion.** Where a production below requires `;`, a `LineTerminator` before an offending token, a `}` , or end of input inserts one, per ECMA-262 §12.10. The *(no LineTerminator here)* restrictions in this grammar are exactly the restricted productions: after `return`, `throw`, `break`, `continue`, and `yield` before their operands; before postfix `++`/`--`; before `=>`; after `async` before its function/arrow; after `accessor` before its member name; after `using` and after the `using` in `await using`; and before the non-null `!`.

Semantic-only constraints are noted narratively and are not encoded in the productions.

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

`LineTerminator` is a distinct input element (not folded into `WhiteSpace` as in Java) because ASI and the *(no LineTerminator here)* restrictions depend on it.

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

A `TraditionalComment` containing a `LineTerminator` counts as a `LineTerminator` for ASI purposes. Certain comments carry compiler meaning (triple-slash directives, `@ts-` pragmas); see §13.

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

The `PredefinedType` exclusion on `TypeIdentifier` applies only where a type name is *introduced* or appears unqualified (§3). After a `.` there is no ambiguity with a predefined type, so `TypeName` admits a full `IdentifierName` on the right of a dot.

### §1.5 Keywords

```
ReservedWord: (one of)
    break      case       catch      class      const
    continue   debugger   default    delete     do
    else       enum       export     extends    false
    finally    for        function   if         import
    in         instanceof new        null       return
    super      switch     this       throw      true
    try        typeof     var        void       while
    with

ContextuallyReservedWord: (one of)
    await      yield      let        static
    implements interface  package    private    protected
    public
```

`await` is reserved in modules and async contexts; `yield` in generators; the remainder in strict-mode code. Since TypeScript 6.0, `alwaysStrict` can no longer be set to `false`, so all input is strict and none of these are available as binding names; the distinction remains semantic.

```
ContextualKeyword: (one of)
    abstract   accessor   any        as         asserts
    async      bigint     boolean    constructor
    declare    defer      from       get        global
    infer      intrinsic  is         keyof      meta
    namespace  never      number     object     of
    out        override   readonly   require    satisfies
    set        string     symbol     target     type
    undefined  unique     unknown    using
```

A contextual keyword is recognized only when it appears as a terminal in the production that admits it; everywhere else it is an ordinary `Identifier`. `assert` and `module` were dropped from this set in 6.0 (see §4.1 and §7).

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
    DecimalIntegerLiteral . [DecimalDigits] [ExponentPart]
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

The separator is never trailing: `1_n` and `1_` are underivable, which is why `DecimalBigIntegerLiteral` and `DecimalIntegerLiteral` each split the separator case into its own alternative rather than bracketing it as optional.

The `BigIntSuffix` attaches to decimal *and* non-decimal numerals (`0xffn`, `0b1011n`, `0o17n`) but never to a fractional or exponent form. Legacy octal (`0777`) and legacy octal escapes are excluded — strict mode. The token after a `NumericLiteral` may not begin with an `IdentifierStart` or `DecimalDigit` (so `3in` is an error, and `1.5` in `{ 1.5: x }` needs no special rule).

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
     LineContinuation — e.g. x or u followed by malformed hex, or a
     DecimalDigit other than a lone 0)
```

`TemplateMiddle` and `TemplateTail` are produced only when the scanner is resumed at the `}` closing a substitution; elsewhere `}` is a `Punctuator`. The `\ NotEscapeSequence` alternative exists for **tagged** templates only (ES2018): the raw text is preserved, the cooked value of the containing span is `undefined`, and in an *untagged* template the same sequence is an unconditional early error.

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

This is deliberately the **lexical** grammar only: it delimits the token (a `/` inside `[...]` or after `\` does not terminate it). The internal pattern grammar — quantifiers including lazy forms (`+?`), named groups, backreferences (`\k<q>`), lookaround, inline modifier groups (`(?i:…)`), and the `v`-mode set notation — is ECMA-262 §22.2 in its entirety and is *not* restated here; enumerating a subset invites exactly the underivability bugs this file replaces. Flag validity (`d g i m s u v y`, no duplicates, `u`/`v` exclusive) is semantic.

### §1.7 Punctuators

```
Punctuator: (one of)
    {    }    (    )    [    ]    .    ...  ;    ,
    <    >    <=   >=   ==   !=   ===  !==  +    -
    *    /    %    **   ++   --   <<   &    |    ^
    !    ~    &&   ||   ??   ?    :    ?.   =    +=
    -=   *=   /=   %=   **=  <<=  &=   |=   ^=   &&=
    ||=  ??=  =>   @
```

`>>`, `>>>`, `>>=`, and `>>>=` are absent by design; see *Deviations*. Each is assembled by the parser from adjacent tokens in `ShiftExpression` and `AssignmentOperator`. `>=` is not formed when its `>` closes a type argument or parameter list (see *Deviations*). `/` and `/=` are produced only where division is admissible (see *Deviations*). `#` appears only inside `PrivateIdentifier` and `HashbangComment`.

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

The second alternative of `Type` is the conditional type. Two separate restrictions apply, and both are structural rather than narrative:

- The **check** type is a `UnionType`, so an unparenthesized function, constructor, or conditional type may not appear there.
- The **extends** operand is a `NonConditionalType`, so a nested conditional must be parenthesized. Without this, `A extends B extends C ? D : E ? F : G` would have two parses with nothing to choose between them; tsc resolves it the same way, by parsing that position with conditional types disallowed.

Distributivity over unions (`T extends unknown ? … : …`) and its suppression by tuple-wrapping (`[T] extends [unknown]`) are semantic. A leading `|` or `&` is admitted (multi-line union style).

```
TypeOperatorType:
    PostfixType
    keyof TypeOperatorType
    readonly TypeOperatorType
    unique TypeOperatorType
    infer TypeIdentifier [extends Type]

PostfixType:
    PrimaryType
    PostfixType [ ]
    PostfixType [ Type ]
```

`readonly` requires an array or tuple operand; `unique` requires `symbol`; `infer` is admitted only within the `extends` clause of a conditional type, and its own `extends` constraint binds to the `infer` (a following `?` belongs to the enclosing conditional). All three restrictions are semantic. `PostfixType [ Type ]` is indexed access; the index may be any type, including `number` and unions of keys.

### §2.2 Primary types

```
PrimaryType:
    ( Type )
    PredefinedType
    TypeReference
    ObjectType
    TupleType
    TypeQuery
    ImportType
    MappedType
    TemplateLiteralType
    LiteralType
    this

PredefinedType: (one of)
    any unknown never void undefined null
    boolean number string symbol object bigint intrinsic

TypeReference:
    TypeName [TypeArguments]

TypeQuery:
    typeof EntityName [TypeArguments]
    typeof ImportType [TypeArguments]

ImportType:
    import ( StringLiteral [, ImportTypeAttributes] )
        [. QualifiedName] [TypeArguments]

ImportTypeAttributes:
    { with : { [WithEntryList [,]] } [,] }

LiteralType:
    StringLiteral
    NumericLiteral
    - NumericLiteral
    BooleanLiteral
    NullLiteral
    NoSubstitutionTemplate
```

`ImportTypeAttributes` is the type-position form of the import attributes of §4.1, sharing its `WithEntryList`; in practice the only attribute the compiler consumes here is `resolution-mode` (`"require"` or `"import"`), which is what makes `import("./m", { with: { "resolution-mode": "import" } }).Foo` expressible. The legacy `assert` spelling is not admitted (§4.1).

The `[TypeArguments]` on `TypeQuery` admits instantiation expressions in type position: `typeof makeBox<bigint>`. The parentheses in `( Type )` are load-bearing against postfix `[]` and union binding: `(() => void)[]`, `(string | number)[]`, `(() => string) | null`.

```
TemplateLiteralType:
    TemplateHead Type {TemplateMiddle Type} TemplateTail
```

Inference from a `TemplateLiteralType` splits on Unicode code points rather than UTF-16 code units as of 7.0; this is semantic, but it changes results for type-level string utilities.

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

`IndexSignature` carries no `static` and no accessibility — those exist only on the class-member form, which prefixes it with `{ClassElementModifier}` (§6). The key `Type` must resolve to `string`, `number`, `symbol`, a template-literal pattern type (`` `data-${string}` ``), or a union of such; semantic. Call, construct, and method signatures may repeat (overload sets), may be generic, and a getter/setter pair may have divergent types; a get/set pair in an object type mirrors the class accessor rules semantically.

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

`Type ?` (unlabeled optional element) is distinguished from a conditional type by context: inside `[ ]` the `?` closes the element. Labels are erased; labeled and unlabeled elements may not mix within one tuple (semantic). A trailing comma is admitted.

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

Overloaded constructor *types* are written as an `ObjectType` with multiple `ConstructSignature`s. `asserts` without `is` narrows nothing; it asserts the condition.

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

The `as` clause remaps keys; a remapped key of `never` (directly or via `Exclude`) drops the member — semantic.

### §2.7 Type parameters and type arguments

```
TypeParameters:
    < TypeParameterList [,] >

TypeParameterList:
    TypeParameter {, TypeParameter}

TypeParameter:
    {TypeParameterModifier} TypeIdentifier [Constraint] [TypeParameterDefault]

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

**`TypeParameters` admits a trailing comma; `TypeArguments` does not.** `Pair<A, B,>` is legal as a parameter list and an error as an argument list (TS1009). The trailing comma exists on the parameter side so that `<T,>` can disambiguate a generic arrow in `.tsx`; it is legal in `.ts` too. `const` is admitted on function, method, and class type parameters; `in`/`out` variance on interface and type-alias parameters; each restriction semantic, as is their relative order (`const` first, `in` before `out`).

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

`TypeName` is left-recursive on itself rather than routed through `NamespaceName`, so the `PredefinedType` exclusion carried by `TypeIdentifier` binds only to the head. `Ns.string` and `Ns.default` are therefore derivable type names, matching tsc's `parseEntityName` with reserved words allowed on the right of a dot. `NamespaceName` is now used only by `NamespaceDeclaration` (§7), where each dotted segment is a real declaration and must be an `Identifier`.

---

## §4 — Programs and Modules

```
Script:
    [ScriptBody]

ScriptBody:
    StatementList

Module:
    [ModuleBody]

ModuleBody:
    ModuleItem {ModuleItem}

ModuleItem:
    ImportDeclaration
    ExportDeclaration
    StatementListItem
```

A `.ts` file containing at least one `import` or `export` at top level is a `Module`; otherwise it is a `Script`. An `ImportEqualsDeclaration` in entity-name form (§4.1) does **not** make the file a module. Directive prologues (§13.3) may open either goal.

### §4.1 Import declarations

```
ImportDeclaration:
    import ImportClause FromClause [WithClause] ;
    import StringLiteral [WithClause] ;
    ImportEqualsDeclaration

FromClause:
    from StringLiteral

ImportClause:
    ImportedDefaultBinding
    NameSpaceImport
    NamedImports
    ImportedDefaultBinding , NameSpaceImport
    ImportedDefaultBinding , NamedImports
    type ImportedDefaultBinding
    type NameSpaceImport
    type NamedImports
    defer NameSpaceImport

ImportedDefaultBinding:
    BindingIdentifier

NameSpaceImport:
    * as BindingIdentifier

NamedImports:
    { [ImportSpecifierList [,]] }

ImportSpecifierList:
    ImportSpecifier {, ImportSpecifier}

ImportSpecifier:
    [type] BindingIdentifier
    [type] ModuleExportName as BindingIdentifier

ModuleExportName:
    IdentifierName
    StringLiteral

WithClause:
    with { [WithEntryList [,]] }

WithEntryList:
    WithEntry {, WithEntry}

WithEntry:
    IdentifierName : StringLiteral
    StringLiteral : StringLiteral

ImportEqualsDeclaration:
    import [type] BindingIdentifier = EntityName ;
    import [type] BindingIdentifier = require ( StringLiteral ) ;
```

A `type`-only import may carry a default binding *or* named bindings, never both (`import type D, { N }` is TS1363 — semantic). `type` inside a specifier may combine with renaming: `type Callback as RenamedCallback`. `type` also combines with the `require` form: `import type FS = require("fs")`. `defer` combines only with a namespace import.

The legacy `assert` keyword for attributes is **removed**, not merely deprecated: TypeScript 6.0 made `import … assert { … }` an error, and 7.0 kept it as a hard error, with `with` the only spelling. The same removal covers the options-bag form `import(specifier, { assert: { … } })` — see §9.2 — and the type-position form of §2.2.

### §4.2 Export declarations

```
ExportDeclaration:
    export ExportFromClause FromClause [WithClause] ;
    export type ExportFromClause FromClause [WithClause] ;
    export NamedExports ;
    export type NamedExports ;
    export VariableStatement
    export Declaration
    export default HoistableDeclaration
    export default ClassDeclaration
    export default AssignmentExpression ;
    export = Expression ;
    NamespaceExportDeclaration

NamespaceExportDeclaration:
    export as namespace Identifier ;

ExportFromClause:
    *
    * as ModuleExportName
    NamedExports

NamedExports:
    { [ExportSpecifierList [,]] }

ExportSpecifierList:
    ExportSpecifier {, ExportSpecifier}

ExportSpecifier:
    [type] ModuleExportName
    [type] ModuleExportName as ModuleExportName
```

`export default AssignmentExpression` applies only when the expression does not begin with `function`, `async function`, or `class` (those parse as the declaration forms; the restriction is the ECMAScript lookahead). `ModuleExportName` as a `StringLiteral` admits arbitrary export names (`export { x as "module local value" }`). `export = ` is the CommonJS-interop assignment; in practice its operand is an `EntityName`, but the parser accepts an expression. At most one default (or `export =`) per module — semantic.

`NamespaceExportDeclaration` is the UMD global declaration (`export as namespace myLib;`). Its operand is a single `Identifier` — dotted names are not supported. It survived the 6.0 module cleanup: it is independent of the removed `--module umd` output mode and is not deprecated. It is legal only at the top level of a declaration file that also has other top-level exports; that restriction, and its interaction with `allowUmdGlobalAccess`, are semantic.

---

## §5 — Declarations, Variables, and Functions

```
Declaration:
    HoistableDeclaration
    ClassDeclaration
    LexicalDeclaration
    TypeAliasDeclaration
    InterfaceDeclaration
    EnumDeclaration
    NamespaceDeclaration
    AmbientDeclaration
    ImportEqualsDeclaration

HoistableDeclaration:
    FunctionDeclaration
    GeneratorDeclaration
    AsyncFunctionDeclaration
    AsyncGeneratorDeclaration
```

### §5.1 Variable and lexical declarations

```
VariableStatement:
    var VariableDeclarationList ;

VariableDeclarationList:
    VariableDeclaration {, VariableDeclaration}

VariableDeclaration:
    BindingIdentifier [!] [TypeAnnotation] [Initializer]
    BindingPattern [TypeAnnotation] Initializer

Initializer:
    = AssignmentExpression

LexicalDeclaration:
    LetOrConst VariableDeclarationList ;
    using (no LineTerminator here) UsingDeclarationList ;
    await (no LineTerminator here) using (no LineTerminator here)
        UsingDeclarationList ;

LetOrConst: (one of)
    let const

UsingDeclarationList:
    UsingDeclaration {, UsingDeclaration}

UsingDeclaration:
    BindingIdentifier [TypeAnnotation] Initializer
```

`!` is the definite-assignment assertion; it excludes an initializer in the same declaration (semantic). `using` bindings must be identifiers with initializers — the grammar encodes both — and `await using` requires an async or top-level-module context (semantic).

```
TypeAliasDeclaration:
    type TypeIdentifier [TypeParameters] = Type ;
```

### §5.2 Function declarations and parameters

```
FunctionDeclaration:
    function BindingIdentifier CallSignature FunctionBodyOrSemicolon

GeneratorDeclaration:
    function * BindingIdentifier CallSignature FunctionBodyOrSemicolon

AsyncFunctionDeclaration:
    async (no LineTerminator here) function BindingIdentifier CallSignature
        FunctionBodyOrSemicolon

AsyncGeneratorDeclaration:
    async (no LineTerminator here) function * BindingIdentifier CallSignature
        FunctionBodyOrSemicolon

FunctionBodyOrSemicolon:
    Block
    ;

FunctionExpression:
    function [BindingIdentifier] CallSignature Block
    function * [BindingIdentifier] CallSignature Block
    async (no LineTerminator here) function [BindingIdentifier] CallSignature Block
    async (no LineTerminator here) function * [BindingIdentifier] CallSignature Block
```

A `;` body makes the declaration an *overload signature*; consecutive overloads must be followed by one implementation whose parameters subsume them (semantic). The name of a named `FunctionExpression` is visible only within its own body.

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

No trailing comma after a `RestParameter`. `ParameterModifier`s other than decorators are *parameter properties* and are legal only on a constructor's parameters; decorators on parameters are likewise position-restricted; `?` and an `Initializer` are mutually exclusive; a `this` parameter is erased and must come first — all semantic. A default may reference an earlier parameter. A rest parameter typed as a labeled tuple (`...args: [label: string, count?: number]`) contributes the labels as call-site parameter names.

### §5.3 Arrow functions

```
ArrowFunction:
    ArrowParameters (no LineTerminator here) => ConciseBody

AsyncArrowFunction:
    async (no LineTerminator here) ArrowParameters
        (no LineTerminator here) => ConciseBody

ArrowParameters:
    BindingIdentifier
    [TypeParameters] ( [ParameterList] ) [ReturnTypeAnnotation]

ConciseBody:
    AssignmentExpression   but not beginning with {
    Block
```

The bare-identifier form admits no type annotation. A body that is an object literal must be parenthesized (`(a, b) => ({ first: a })`); the `but not` encodes it. Generic arrows (`<T>(v: T): T => v`) are unambiguous in `.ts` per the cover resolution in *Deviations*.

---

## §6 — Classes

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

The `extends` operand is an *expression* (mixin patterns: `class extends Base { … }` where `Base` is a parameter), optionally instantiated with `TypeArguments` (`extends Box<number>`). The name of a named `ClassExpression` is visible only inside the class body. `export default class { … }` is a `ClassDeclaration` with the name omitted.

```
ClassBody:
    {ClassElement}

ClassElement:
    ConstructorDeclaration
    PropertyDeclaration
    MethodDeclaration
    AccessorFieldDeclaration
    GetAccessor
    SetAccessor
    ClassIndexSignature
    StaticBlock
    ;

ClassElementModifier: (one of)
    public protected private static abstract override
    readonly declare async

ClassElementName:
    PropertyName
    PrivateIdentifier

ConstructorDeclaration:
    {ClassElementModifier} constructor
        ( [ParameterList] ) FunctionBodyOrSemicolon

PropertyDeclaration:
    {Decorator} {ClassElementModifier} ClassElementName [? or !]
        [TypeAnnotation] [Initializer] ;

MethodDeclaration:
    {Decorator} {ClassElementModifier} [*] ClassElementName [?]
        CallSignature FunctionBodyOrSemicolon

AccessorFieldDeclaration:
    {Decorator} {ClassElementModifier} accessor (no LineTerminator here)
        ClassElementName [TypeAnnotation] [Initializer] ;

GetAccessor:
    {Decorator} {ClassElementModifier} get ClassElementName ( )
        [TypeAnnotation] FunctionBodyOrSemicolon

SetAccessor:
    {Decorator} {ClassElementModifier} set ClassElementName
        ( FormalParameter ) FunctionBodyOrSemicolon

ClassIndexSignature:
    {ClassElementModifier} IndexSignature ;

StaticBlock:
    static { [StatementList] }
```

**`accessor` is a terminal of `AccessorFieldDeclaration`, not a member of `ClassElementModifier`.** Listing it in both places makes `accessor x;` ambiguous — derivable either as an auto-accessor field named `x` or as a plain field named `x` carrying an `accessor` modifier. Only the first is intended. The *(no LineTerminator here)* after `accessor` is the restricted production from the auto-accessor proposal: a line break there makes `accessor` an ordinary field name.

**Constructors admit no decorators** — a decorated constructor is rejected at parse time (TS1206), so `ConstructorDeclaration` carries no `{Decorator}`; a constructor's *parameters* may be decorated via `ParameterModifier`. Modifier legality and order are semantic: accessibility first, then `static`, then `abstract`/`override`, then `readonly`, with `declare` excluding an initializer, `abstract` excluding a body, `async` and `*` combining for async generator methods, `accessor` combining with `static`, and `abstract override` legal together. Overload signatures (`;` bodies) apply to constructors and methods. Private members (`#x`) may be fields, methods, accessors, and static forms; `static` private members and private accessors are ordinary combinations. Computed names admit generators (`*[Symbol.iterator]()`), and `PropertyName` covers identifier, string, numeric, and computed keys:

```
PropertyName:
    IdentifierName
    StringLiteral
    NumericLiteral
    ComputedPropertyName

ComputedPropertyName:
    [ AssignmentExpression ]
```

---

## §7 — Interfaces, Enums, and Namespaces

```
InterfaceDeclaration:
    interface TypeIdentifier [TypeParameters] [InterfaceExtendsClause]
        ObjectType

InterfaceExtendsClause:
    extends ClassTypeList
```

Repeated `interface` declarations of one name merge; so do function+namespace, class+namespace, and enum+namespace pairs. Merging is entirely semantic.

```
EnumDeclaration:
    [const] enum BindingIdentifier { [EnumMemberList [,]] }

EnumMemberList:
    EnumMember {, EnumMember}

EnumMember:
    EnumMemberName [= AssignmentExpression]

EnumMemberName:
    IdentifierName
    StringLiteral
```

`EnumMemberName` is **not** a `PropertyName`: computed and numeric names are excluded by construction, string names (`"Content-Type"`) are admitted. Constant-versus-computed member initializers, heterogeneous enums, and reverse mappings are semantic.

```
NamespaceDeclaration:
    namespace NamespaceName { NamespaceBody }

NamespaceBody:
    {NamespaceElement}

NamespaceElement:
    StatementListItem
    export Declaration
    export NamedExports ;
    ExportDeclaration but not a form with FromClause or default or =
```

**`namespace` is the only spelling.** The legacy `module Foo { … }` alternative is gone: TypeScript 6.0 made it a hard deprecation and 7.0 made it an error, on the grounds that ECMAScript's prospective `module` blocks would collide with it. The change also removes `declare module Foo { … }` with a bare identifier, which reached the same production through §12. Ambient modules named by a *string literal* are unaffected and keep their own production (§12).

A dotted `NamespaceName` (`Outer.Inner.Deep`) declares nested namespaces, each implicitly exported.

---

## §8 — Statements

```
Statement:
    Block
    VariableStatement
    EmptyStatement
    ExpressionStatement
    IfStatement
    BreakableStatement
    ContinueStatement
    BreakStatement
    ReturnStatement
    WithStatement
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
    Expression ;   but not beginning with { or function or async function
                   or class or let [
```

The `but not` list is the ECMAScript lookahead restriction: those openers parse as a block or declaration instead, which is why object-literal destructuring assignments are parenthesized (§10). `WithStatement` is retained for completeness but is unreachable in practice: all input is strict, and since 6.0 that can no longer be turned off.

```
IfStatement:
    if ( Expression ) Statement else Statement
    if ( Expression ) Statement
```

The dangling `else` binds to the nearest unmatched `if`; `mocha` resolves the ambiguity that way rather than via `NoShortIf` stratification. TypeScript additionally rejects an `EmptyStatement` as the body of an `if` (TS1313) — semantic.

```
IterationStatement:
    do Statement while ( Expression ) ;
    while ( Expression ) Statement
    for ( [ForInit] ; [Expression] ; [Expression] ) Statement
    for ( ForInHead in Expression ) Statement
    for ( ForOfHead of AssignmentExpression ) Statement
    for await ( ForOfHead of AssignmentExpression ) Statement

ForInit:
    Expression   but not beginning with let [
    var VariableDeclarationList
    LetOrConst VariableDeclarationList

ForInHead:
    LeftHandSideExpression
    var ForBinding
    LetOrConst ForBinding

ForOfHead:
    LeftHandSideExpression   but not beginning with let or async of
    var ForBinding
    LetOrConst ForBinding
    using (no LineTerminator here) ForBinding   but not beginning with of
    await (no LineTerminator here) using (no LineTerminator here) ForBinding
        but not beginning with of

ForBinding:
    BindingIdentifier
    BindingPattern
```

`ForBinding` carries **no** `TypeAnnotation`: an annotation on a `for`-`in`/`for`-`of` binding is TS2483/TS2404, so the grammar excludes it. `await using` is reachable both as a `LexicalDeclaration` (§5.1) and here as a for-of head; `using` heads take identifier bindings only (semantic). The `but not beginning with of` restriction on the `using` heads is the proposal's `[lookahead ≠ of]`: in `for (using of x)` the word `using` is an ordinary identifier `LeftHandSideExpression`, not a declaration head. `for await` requires an async or top-level-module context (semantic).

```
ContinueStatement:
    continue (no LineTerminator here) [Identifier] ;

BreakStatement:
    break (no LineTerminator here) [Identifier] ;

ReturnStatement:
    return (no LineTerminator here) [Expression] ;

ThrowStatement:
    throw (no LineTerminator here) Expression ;

DebuggerStatement:
    debugger ;

LabelledStatement:
    Identifier : Statement
```

A label may prefix any statement, including a plain `Block`; `break label` out of a labelled block is the non-loop form, while `continue` requires its label to denote an enclosing loop (semantic).

```
SwitchStatement:
    switch ( Expression ) CaseBlock

CaseBlock:
    { {CaseClause} [DefaultClause {CaseClause}] }

CaseClause:
    case Expression : [StatementList]

DefaultClause:
    default : [StatementList]
```

The `CaseBlock` may be empty; `default` may sit in any position, including non-final, and fallthrough — including out of a non-final `default` — is expressed simply by the absence of a transfer statement. At most one `default` (semantic).

```
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

The catch binding is optional (ES2019). A `TypeAnnotation` on a catch parameter must be `any` or `unknown` — semantic — and a destructuring pattern may carry the annotation on the whole pattern.

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
    [async (no LineTerminator here)] [*] PropertyName CallSignature Block
    get PropertyName ( ) [TypeAnnotation] Block
    set PropertyName ( FormalParameter ) Block
```

`FunctionExpression` (§5.2) already carries the generator, async, and async-generator alternatives, so `PrimaryExpression` names it once and no separate generator/async entry appears here.

The three `ArrayLiteral` alternatives are ECMA-262's: the first covers elision-only arrays of any length (`[]`, `[,]`, `[,,]`), the third covers a trailing comma with or without trailing holes (`[1,]`, `[1,,]`). Object-literal methods admit generators, async generators, and computed or quoted names on accessors (`set ["computed" + "Name"](n)`). The `Identifier` alternative is shorthand. `Identifier = AssignmentExpression` (`CoverInitializedName`) is admitted only when the literal is re-interpreted as an assignment pattern (§10.2), never as a value.

### §9.2 Left-hand-side expressions

```
MemberExpression:
    PrimaryExpression
    MemberExpression [ Expression ]
    MemberExpression . IdentifierName
    MemberExpression . PrivateIdentifier
    MemberExpression (no LineTerminator here) !
    MemberExpression TemplateLiteral
    SuperProperty
    MetaProperty
    new MemberExpression [TypeArguments] Arguments

SuperProperty:
    super [ Expression ]
    super . IdentifierName

MetaProperty:
    new . target
    import . meta

NewExpression:
    MemberExpression
    new NewExpression

CallExpression:
    MemberExpression [TypeArguments] Arguments
    SuperCall
    ImportCall
    CallExpression [TypeArguments] Arguments
    CallExpression [ Expression ]
    CallExpression . IdentifierName
    CallExpression . PrivateIdentifier
    CallExpression (no LineTerminator here) !
    CallExpression TemplateLiteral

SuperCall:
    super [TypeArguments] Arguments

ImportCall:
    import ( AssignmentExpression [,] )
    import ( AssignmentExpression , AssignmentExpression [,] )

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
    ?. TemplateLiteral
    OptionalChain [TypeArguments] Arguments
    OptionalChain [ Expression ]
    OptionalChain . IdentifierName
    OptionalChain . PrivateIdentifier
    OptionalChain TemplateLiteral
    OptionalChain (no LineTerminator here) !

LeftHandSideExpression:
    NewExpression
    CallExpression
    InstantiationExpression
    OptionalExpression
```

`new NewExpression` with no `Arguments` (`new Date`) binds any following member accesses into the constructor expression first. Spread is admitted in `Arguments`, hence in `new` expressions. The postfix `!` is the non-null assertion. An `InstantiationExpression` — `TypeArguments` with no following `Arguments` — is chosen per the predicate in *Deviations*, which admits every position in `makeBox<string>;`, `[makeBox<number>, makeBox<string>]`, `{ num: makeBox<number> }`, `(makeBox<boolean>)(true)`, and `cond ? makeBox<number> : makeBox<number>`. `?.<T>(…)` is the optional call with explicit type arguments. The second argument of `ImportCall` is the options object, and a trailing comma is admitted after either argument; since 6.0 an `assert` key in that object is an error, and only `with` is accepted. The two `TemplateLiteral` alternatives inside `OptionalChain` exist in ECMA-262 solely to carry an **unconditional early error**: a tagged template in an optional chain is always a syntax error — the productions are kept so the construct is derivable and then statically rejected, matching the ES specification's structure. Type arguments on `SuperCall` parse but are always rejected (semantic). `PrivateIdentifier` also appears as a relational operand (`#secret in candidate`, §9.5).

### §9.3 Update, unary, and cast expressions

```
UpdateExpression:
    LeftHandSideExpression
    LeftHandSideExpression (no LineTerminator here) ++
    LeftHandSideExpression (no LineTerminator here) --
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

`< Type > UnaryExpression` is the angle-bracket type assertion, legal in `.ts` only, and resolved against generic arrows per *Deviations*. `await` requires an async or top-level-module context; `delete`'s operand restrictions are semantic.

### §9.4 Exponentiation, multiplicative, additive, shift

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
```

`**` is right-associative, and its left operand is an `UpdateExpression`, not a `UnaryExpression` — `-a ** b` is a syntax error without parentheses; the stratification encodes it. The spaced `> >` and `> > >` are adjacent-token joins per *Deviations*.

### §9.5 Relational, equality, and TS operand operators

```
RelationalExpression:
    ShiftExpression
    RelationalExpression < ShiftExpression
    RelationalExpression > ShiftExpression
    RelationalExpression <= ShiftExpression
    RelationalExpression >= ShiftExpression
    RelationalExpression instanceof ShiftExpression
    RelationalExpression in ShiftExpression
    PrivateIdentifier in ShiftExpression
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

`in` is excluded from `RelationalExpression` inside a classic `for` head's init (encoded narratively rather than by parameterization). `as unknown as Foo` is simply two applications. `as const` also applies to object literals, array literals, and other literal operands.

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
    yield (no LineTerminator here) AssignmentExpression
    yield (no LineTerminator here) * AssignmentExpression

Expression:
    AssignmentExpression
    Expression , AssignmentExpression
```

`??` may not mix unparenthesized with `&&` or `||` — the split into `LogicalORExpression` and `CoalesceExpression` under `ShortCircuitExpression` encodes it. Per ECMA-262, a `CoalesceExpression` exists only once at least one `??` is present (a bare `BitwiseORExpression` reaches `ShortCircuitExpression` only through the `LogicalORExpression` arm, keeping the derivation unambiguous). `?:` is right-associative by construction. The assignment-pattern alternatives are §10.2; the destructured LHS otherwise arises by re-interpreting an `ObjectLiteral`/`ArrayLiteral`. `yield*` delegates to any iterable; `yield` as a value-receiving expression is the plain form in expression position.

---

## §10 — Patterns

### §10.1 Binding patterns (declaration position)

```
BindingPattern:
    ObjectBindingPattern
    ArrayBindingPattern

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

`PropertyName` admits computed keys inside patterns (`{ [keyName]: computedValue = 0 }`); a default may itself destructure (`{ config: { retries = 3 } = {} }`); elisions skip elements; any iterable — strings, Sets — may be array-destructured (semantic).

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

A target may be any assignable `LeftHandSideExpression` — `[target.x, target.y] = [3, 4]` — not just a binding. An `ObjectAssignmentPattern` in statement position must be parenthesized, per the `ExpressionStatement` lookahead (§8); an `ArrayAssignmentPattern` needs no parentheses.

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

Decorators appear on class declarations/expressions (before or after `export`, not both — semantic), on methods, fields, accessors, `accessor` fields, getters, and setters, and on constructor parameters — but never on constructors themselves (§6). Which member kinds a given decorator may target, and the `Symbol.metadata` protocol, are API-level, not grammar.

---

## §12 — Ambient Declarations

```
AmbientDeclaration:
    declare AmbientVariableStatement
    declare AmbientFunctionDeclaration
    declare AmbientClassDeclaration
    declare AmbientEnumDeclaration
    declare NamespaceDeclaration
    declare AmbientModuleDeclaration
    declare global { NamespaceBody }

AmbientVariableStatement:
    var AmbientBindingList ;
    let AmbientBindingList ;
    const AmbientBindingList ;

AmbientBindingList:
    AmbientBinding {, AmbientBinding}

AmbientBinding:
    BindingIdentifier [TypeAnnotation]

AmbientFunctionDeclaration:
    function BindingIdentifier CallSignature ;

AmbientEnumDeclaration:
    [const] enum BindingIdentifier { [EnumMemberList [,]] }

AmbientModuleDeclaration:
    module StringLiteral { NamespaceBody }
    module StringLiteral ;
```

`AmbientModuleDeclaration` is the **only** surviving use of the `module` keyword: its operand is always a `StringLiteral`. `declare module Foo { … }` with a bare identifier reached this section through `declare NamespaceDeclaration` and is no longer derivable, matching its removal in 6.0 (§7).

An ambient module takes a braced body **or** a bare semicolon (`declare module "some-untyped-package";`) — never both. The `StringLiteral` may be a wildcard pattern (`"*.css"`) or any specifier. `declare const x: unique symbol` is the standard idiom the `unique` operator (§2.1) exists for.

```
AmbientClassDeclaration:
    [abstract] class BindingIdentifier [TypeParameters] [ClassHeritage]
        { {AmbientClassBodyElement} }

AmbientClassBodyElement:
    {ClassElementModifier} constructor ( [ParameterList] ) ;
    {ClassElementModifier} ClassElementName [? or !] [TypeAnnotation] ;
    {ClassElementModifier} [*] ClassElementName [?] CallSignature ;
    {ClassElementModifier} accessor (no LineTerminator here)
        ClassElementName [TypeAnnotation] ;
    {ClassElementModifier} get ClassElementName ( ) [TypeAnnotation] ;
    {ClassElementModifier} set ClassElementName ( FormalParameter ) ;
    {ClassElementModifier} IndexSignature ;
```

Ambient class members take the **full** `ClassElementModifier` set — `static`, `private static`, `readonly`, `protected`, `abstract`, `protected abstract readonly` — and getter/setter signatures; only bodies and initializers are excluded. Index signatures take modifiers here for the same reason they do in §6. Inside a `declare`d container, nested declarations are implicitly ambient and `declare` may not be repeated (semantic).

---

## §13 — Comment-Position Grammar

Lexically these are comments and string literals; the compiler assigns them meaning by position.

### §13.1 Triple-slash directives

```
TripleSlashDirective:
    / / / < reference DirectiveAttribute {DirectiveAttribute} / >

DirectiveAttribute:
    path = StringLiteral
    types = StringLiteral
    lib = StringLiteral
    resolution-mode = StringLiteral
```

Recognized only in the *directive region*: before every statement in the file. Ordinary comments may precede a directive; any statement — including a `"use strict"` prologue — ends the region. `resolution-mode` (value `"require"` or `"import"`) is legal only alongside `types`; one primary attribute per directive — both semantic.

Three attributes that appeared in earlier versions are gone. `no-default-lib` was removed in 6.0 (`--noLib` or `--libReplacement` replace it) and is no longer respected in 7.0. `amd-module` and `amd-dependency` lost all effect when `--module amd` was removed.

### §13.2 Check-control pragmas

```
CheckPragma:
    / / @ts-expect-error {InputCharacter}
    / / @ts-ignore {InputCharacter}
    / / @ts-nocheck {InputCharacter}
    / / @ts-check {InputCharacter}
```

`@ts-expect-error` and `@ts-ignore` attach to the *next line* (not the enclosing statement — a pragma inside a multi-line expression suppresses only the following line); `@ts-expect-error` is itself an error if that line is clean (TS2578). `@ts-nocheck` and `@ts-check` are file-level and must precede all statements; `@ts-nocheck` applies in `.ts` files as well as `.js`, while `@ts-check` is meaningful only in checked-JavaScript files.

### §13.3 Directive prologues

```
DirectivePrologue:
    {ExpressionStatement whose Expression is a StringLiteral}
```

The longest initial run of string-literal expression statements in a `Script`, `Module`, or function body. `"use strict"` within it is the Use Strict Directive; a function with a non-simple parameter list (default, rest, or destructured) may not contain one (TS1347). A string-literal statement after any other statement is an ordinary expression statement. Since 6.0 all code is strict regardless, so the directive is redundant but still legal.