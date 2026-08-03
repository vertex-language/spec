# Vertex Grammar

Goal symbols: `SourceFile` (syntactic), `InputElement` (lexical).

This document defines syntax only. Static rules, error diagnostics, runtime
semantics, and library surfaces are specified elsewhere.

---

## 1. Notation

```
Nonterminal ::            lexical production
Nonterminal :             syntactic production
Nonterminal :: one of     each terminal is one alternative
```

`Symbolopt` — the symbol may be omitted; *n* optional symbols abbreviate 2ⁿ
productions.

`X but not Y` — any X that is not also Y.

`[lookahead ≠ t]` / `[lookahead ∉ Set]` — the next input element may not be the
given terminal, or may not be drawn from the given set.

`[empty]` — matches no input.

### 1.1 Context parameters

Four parameters carry context through the syntactic grammar.

| Parameter | Set by |
| --- | --- |
| `Await` | an `async`-marked function body; `main` |
| `Npu` | an `npu`-marked function body |
| `Own` | an owning position (§1.2) |
| `Lit` | any expression position other than a control-flow header |

References are written `Nonterminal[+P]`, `Nonterminal[~P]`, `Nonterminal[?P]`.
A guarded alternative `[+P] alternative` exists only when the parameter is set;
`[~P] alternative` only when it is not.

A parameter not written on a right-hand-side reference propagates unchanged from
the left-hand side; only a change of context is annotated. Propagation stops at a
`FunctionExpression`, which begins with all four parameters cleared.

### 1.2 Owning positions

`Own` is set in exactly these positions:

* the right-hand side of a `VariableDeclaration` or `AssignmentStatement`;
* an argument;
* an element of a tuple, array, map, or composite literal;
* a returned expression;
* the binding of a consuming `for` loop.

`Own` does not propagate into subexpressions.

### 1.3 Statement termination

There is no statement terminator token. A statement ends at a `LineTerminator` or
at the `}` closing its block. A line break inside `(`…`)`, `[`…`]`, or `{`…`}` is
ordinary whitespace. Where a production lists two symbols in sequence, whitespace
including line terminators may separate them unless `[no LineTerminator here]`
appears.

---

## 2. Lexical Grammar

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

### 2.1 Comments

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

A `MultiLineComment` does not nest. A `Comment` containing a `LineTerminator` is
itself a `LineTerminator` for §1.3.

### 2.2 Identifiers

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
    any Unicode code point with the property "ID_Start"

UnicodeIDContinue ::
    any Unicode code point with the property "ID_Continue"

BlankIdentifier ::
    _
```

### 2.3 Keywords

```
Keyword :: one of
    abstract    as          async       await       break       case
    chan        class       constraint  continue    declare     default
    defer       else        enum        fallthrough for         func
    gpu         if          import      in          let         map
    mut         npu         package     return      select      shared
    struct      switch      tensor      thread      type        typed_ptr
    unique      var         vector      weak        while

ReservedLiteralKeyword :: one of
    true        false       nil

ContextualKeyword :: one of
    build       deinit      error       framework   init        module
    test
```

A `ContextualKeyword` is an `Identifier` everywhere except the production that
names it literally.

### 2.4 Predeclared type names

```
PredeclaredTypeName :: one of
    int     int8    int16   int32   int64
    uint    uint8   uint16  uint32  uint64
    byte    float32 float64 bool    char    string
```

### 2.5 Literals

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

#### 2.5.1 Numeric

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

There is no negative-number literal; `-1000` is unary minus applied to `1000`.

#### 2.5.2 String and character

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

No escape sequence is recognised inside a backtick string.

### 2.6 Punctuators

```
Punctuator :: one of
    (   )   [   ]   {   }   ,   .   ..  ...  :   ->
    =   +=  -=  *=  /=  %=  &=  |=  ^=  <<= >>=
    +   -   *   /   %   ~   &   |   ^   <<  >>
    &+  &-  &*
    ==  !=  <   >   <=  >=  === !==
    &&  ||  !
```

The longest matching punctuator wins.

---

## 3. Source File

```
SourceFile :
    PackageClause BuildClauseopt ImportDeclarationsopt TopLevelDeclarationsopt

PackageClause :
    package Identifier

BuildClause :
    build BuildTag

BuildTag :: one of
    linux   windows darwin  js      wasm    test

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

Implementations may recognise additional `BuildTag` terminals.

---

## 4. Types

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
    VectorType
    InstantiatedType

TypeName :
    Identifier
    PredeclaredTypeName

QualifiedTypeName :
    Identifier . Identifier

ArrayType :
    [ ArrayLength ] Type

ArrayLength :
    IntegerLiteral
    Identifier

SliceType :
    [ ] Type

MapType :
    map [ Type ] Type

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

OwnershipQualifiedType :
    mut Type
    var Type
    unique Type
    shared Type
    weak Type

PointerType :
    typed_ptr Type
    typed_ptr ( PointerType )

AbstractType :
    abstract

FunctionType :
    func ( TypeListopt ) ReturnTypeopt

TypeList :
    Type
    TypeList , Type

ReturnType :
    -> Type
    -> ExpectedType

ChannelType :
    chan Type

TensorType :
    tensor [ Type , ShapeList ]

ShapeList :
    IntegerLiteral
    ShapeList , IntegerLiteral

VectorType :
    vector [ Type , IntegerLiteral ]

InstantiatedType :
    TypeName TypeArguments
    QualifiedTypeName TypeArguments
```

`VectorType` is not guarded by a context parameter — unlike `TensorType`, it is
legal wherever a `Type` is. Where it is and is not permitted to actually appear
is a static rule, not a syntactic one.

---

## 5. Expressions

```
Expression[?Await, ?Lit] :
    LogicalORExpression

ExpressionList :
    Expression
    ExpressionList , Expression
```

### 5.1 Primary

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
    TypeOperatorCall
    VectorConstructorCall

NamespaceExpression :: one of
    async   gpu     npu     chan

FunctionExpression :
    func ( ParameterListopt ) FunctionMarkeropt ReturnTypeopt Block

EnumShorthand :
    . Identifier
    . Identifier ( ExpressionListopt )
```

### 5.2 Type-operator calls

The only call forms that take a `Type` in argument position. All other builtins
parse as ordinary `CallExpression`.

```
TypeOperatorCall :
    sizeof ( Type )
    alignof ( Type )
    reinterpret ( Type , Expression )
```

### 5.2.1 Vector construction

A `VectorType` in expression position is a fourth type-operator-shaped form, but
is kept as its own production rather than folded into `TypeOperatorCall`: its
callee is a `VectorType`, not a bare `Type`, and it is never a
`PostfixExpression` — no `CallExpression` reading applies to it.

```
VectorConstructorCall :
    VectorType ( Expression )
    VectorType ( Expression , Expression )
```

Which of the two forms applies, and what each means, is a static rule.

### 5.3 Launch and call

```
LaunchExpression[?Await] :
    thread CallExpression
    async [lookahead ≠ .] CallExpression
    gpu LaunchConfigopt [lookahead ≠ .] CallExpression
    npu [lookahead ≠ .] CallExpression

LaunchConfig :
    ( blocks : Expression , threads : Expression )

CallExpression[?Await, ?Lit] :
    PostfixExpression Arguments
    PostfixExpression TypeArguments Arguments

AwaitExpression :
    await UnaryExpression
```

### 5.4 Postfix

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

`&` binds tighter than `.`.

### 5.5 Unary and cast

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

### 5.6 Binary cascade

Listed tightest-binding first. Every level except `..` is left-associative; `..`
is non-associative.

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

### 5.7 Ownership marker

```
OwningExpression[?Own] :
    [+Own] var TransferTarget
    Expression

TransferTarget :
    Identifier
    TransferTarget . Identifier
```

### 5.8 Literals

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

---

## 6. Statements

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

### 6.1 Variable declarations

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

### 6.2 Assignment

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

### 6.3 Control flow

```
IfStatement[?Await] :
    if Expression[~Lit] Block
    if Expression[~Lit] Block else Block
    if Expression[~Lit] Block else IfStatement

WhileStatement[?Await] :
    while Expression[~Lit] Block

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
    CallExpression
    [+Await] await CallExpression
```

Which calls are admissible in `ChannelCase` position is a static rule.

### 6.4 Jumps and other statements

```
ReturnStatement :
    return
    return OwningExpressionList[+Own]

OwningExpressionList :
    OwningExpression
    OwningExpressionList , OwningExpression

DeferStatement :
    defer PostfixExpression Arguments

BreakStatement :
    break

ContinueStatement :
    continue

FallthroughStatement :
    fallthrough

ExpressionStatement[?Await] :
    Expression[+Lit] but not one of CompositeLiteral or MapLiteral
```

---

## 7. Declarations

### 7.1 Functions

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

InitializerDeclaration :
    func ( Identifier : ReceiverType ) init ( ParameterListopt ) Block

DeinitializerDeclaration :
    func ( Identifier : ReceiverType ) deinit ( ) Block
```

A function carries at most one `FunctionMarker`.

### 7.2 Types

```
StructDeclaration :
    struct Identifier TypeParameterListopt { FieldListopt }

ClassDeclaration :
    class Identifier TypeParameterListopt { FieldListopt }

FieldList :
    Field
    FieldList Field

Field :
    Identifier : Type
    Identifier : Type = Expression

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

TypeAliasDeclaration :
    type Identifier TypeParameterListopt = AliasTarget

AliasTarget :
    Type
    AbstractType
```

*Note: `FieldList` (§7.2) is now comma-free, newline-separated juxtaposition — this is a change from prior revisions of this grammar. `VariantList` (enum) and `TupleElementList`/`TupleElementValueList` (§4, §5.8) still require commas and are unchanged.*

---

## 8. Generics

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

ConstraintExpression :
    ConstraintName
    TypeSet

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

TypeSet :
    TypeSetTerm
    TypeSet | TypeSetTerm

TypeSetTerm :
    Type
    ~ Type

InstantiationExpression :
    PostfixExpression TypeArguments Arguments
```

A single identifier in constraint position parses as both a one-term `TypeSet`
and a `ConstraintName`; resolution is by what the name denotes.

---

## 9. Declare Blocks

```
DeclareDeclaration :
    declare framework StringLiteral DeclareBody
    declare module VariantTagopt StringLiteral DeclareBody

VariantTag :
    [ StringLiteralList ]

StringLiteralList :
    StringLiteral
    StringLiteralList , StringLiteral

DeclareBody :
    { DeclareMemberListopt }

DeclareMemberList :
    DeclareMember
    DeclareMemberList DeclareMember

DeclareMember :
    ForeignFunctionDeclaration
    ForeignClassDeclaration

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

Foreign declarations have no body and no fields. `VectorType` is not admissible
as a `ForeignFunctionDeclaration` parameter or result type (proposed_vector.md
§3.4.2); this restriction is a static rule, since the syntax productions here
draw no distinction among `Type` alternatives.

---

## 10. Test Result Types

```
ExpectedType :
    Expected ( TypeName , StringLiteral )
    Expected ( error )
    Expected ( error , StringLiteral )
```