# Vertex Grammar

**Version 3.** Goal symbol: `SourceFile`.

This document defines syntax only, and is the single source of truth for it. Static
rules, diagnostics, lowering, and library surfaces are specified elsewhere
(`semantics.md`, `lowering.md`). Where this document says "static rule," it means the
form derives and is checked after parsing.

---

## Notation

The syntax is specified using a variant of Extended Backus-Naur Form (EBNF):

```
Syntax      = { Production } .
Production  = production_name "=" [ Expression ] "." .
Expression  = Term { "|" Term } .
Term        = Factor { Factor } .
Factor      = production_name | token [ "…" token ] | Group | Option | Repetition .
Group       = "(" Expression ")" .
Option      = "[" Expression "]" .
Repetition  = "{" Expression "}" .
```

Operators, in increasing precedence:

```
|   alternation
()  grouping
[]  option (0 or 1 times)
{}  repetition (0 to n times)
```

Lowercase production names identify lexical (terminal) tokens. Non-terminals are in
CamelCase. Lexical tokens are enclosed in double quotes `""`. The form `a … b` is the
set of characters from `a` through `b` as alternatives. Text between `/*` and `*/` is
an informal description not further specified here.

A name written in double quotes that is not a keyword matches an `identifier` token
with that spelling; see *Contextual keywords*.

---

## Source code representation

Source code is Unicode text encoded in UTF-8. The text is not canonicalized. Each code
point is distinct; uppercase and lowercase letters are different characters.

A compiler must reject the NUL character (U+0000) in source text. A UTF-8-encoded byte
order mark (U+FEFF) is ordinary white space wherever it appears.

### Characters

```
line_terminator     = /* U+000A, U+000D, U+000D U+000A, U+2028, or U+2029 */ .
white_space         = /* U+0009, U+000B, U+000C, U+0020, U+00A0, U+FEFF, or any code point in category Zs */ .
unicode_char        = /* an arbitrary Unicode code point except line_terminator */ .
unicode_id_start    = /* a code point with the Unicode ID_Start property */ .
unicode_id_continue = /* a code point with the Unicode ID_Continue property */ .
```

`ID_Start` and `ID_Continue` are the derived properties of the Unicode Standard, pinned
to a stated Unicode version. An implementation must not derive them from a host
toolchain whose version may drift.

### Digits

```
decimal_digit = "0" … "9" .
binary_digit  = "0" | "1" .
octal_digit   = "0" … "7" .
hex_digit     = "0" … "9" | "A" … "F" | "a" … "f" .
```

---

## Lexical elements

### Comments

There are two forms:

1. *Line comments* start with `//` and stop at the end of the line.
2. *General comments* start with `/*` and stop with the first subsequent `*/`. General
   comments do not nest.

A comment cannot start inside a character or string literal, or inside a comment. A
general comment containing no line terminator acts like white space. Any other comment
acts like a line terminator.

### Tokens

Tokens form the vocabulary of the language. There are four classes: *identifiers*,
*keywords*, *operators and punctuation*, and *literals*. White space is ignored except
as it separates tokens that would otherwise combine into a single token. While breaking
the input into tokens, the next token is the longest sequence of characters that forms a
valid token, subject to the one restriction in *Numeric literals after a selector dot*
below.

### Statement termination

There is no statement terminator token and no automatic semicolon insertion. The formal
syntax writes `terminator` where a construct must end.

```
terminator = line_terminator { line_terminator } .
```

A run of consecutive line terminators is **one** `terminator`. Blank lines and
comment-only lines are therefore absorbed wherever a `terminator` is admissible, and
every brace-delimited terminator-separated list below is written with a leading
`[ terminator ]` so that a list may also open with a blank line.

A `terminator` may be omitted:

1. immediately before a closing `"}"`,
2. immediately before `"case"` or `"default"`,
3. at end of file.

#### Where a line terminator is significant

**Rule.** A line terminator is a `terminator` if and only if the innermost enclosing
bracketing construct is one whose production writes `terminator`. Otherwise it is
ordinary white space. The source file itself counts as such a construct.

This is a parser rule, not a lexical one: the scanner emits every line terminator and
interprets none of them. Whether a given `"{"` opens a `Block` or a `LiteralValue` is a
parsing question, so a line terminator is never suppressed or synthesized lexically.

Terminator-significant bracketing constructs — those whose productions write
`terminator`:

* `SourceFile` (top level)
* `Block`
* a `StructDecl` or `ClassDecl` body
* a `ConstraintDecl` body
* a `SwitchStmt` or `SelectStmt` body, and the `StatementList` of each of its clauses
* a `DeclareBody` and a `ForeignClassDecl` body

Everything else is not: `"("`…`")"`, `"["`…`"]"`, `Arguments`, `Parameters`,
`LaunchConfig`, `TypeArgs`, `TypeParameters`, `LiteralValue`, `MapLit`, `ArrayLit`,
`TupleLit`, and an `EnumDecl` body.

Because the rule keys on the *innermost* construct, it nests correctly. A multi-statement
`FunctionLit` passed as an argument sits inside `Arguments`, but its own `Block` is the
innermost enclosing construct, so its statements are terminated normally:

```vertex
let doubled = process(nums, func(n: int32) -> int32 {
    let m = n * 2
    return m
})
```

### Identifiers

```
identifier = ( unicode_id_start | "_" ) { unicode_id_continue | "_" } .
```

The character `"$"` is not an identifier character in any position.

```
a
_x9
αβ
_           // the blank identifier
```

The identifier `"_"` is the *blank identifier*: it introduces no binding. `_` is an
ordinary `identifier` token, so productions below write `identifier` and never
`identifier | "_"`. Which positions accept the blank identifier, and what it means
there, is a static rule.

### Keywords

The following keywords are reserved and may not be used as identifiers:

```
abstract     class        enum         let          shared       typed_ptr
as           constraint   fallthrough  map          struct       unique
async        continue     for          mut          switch       var
await        declare      func         npu          tensor       vector
break        default      gpu          package      thread       weak
case         defer        if           return       type         while
chan         else         import       select
             in
```

The following are reserved literal keywords. They are literals syntactically but are
reserved lexically, and are therefore never identifiers:

```
true         false        nil
```

### Contextual keywords

A contextual keyword is an ordinary `identifier` everywhere except the productions that
name it literally. The complete set — every name this document writes in double quotes
that is not a keyword:

| Name | Recognized in |
|---|---|
| `build` | `BuildClause` |
| `linux`, `windows`, `darwin`, `js`, `wasm`, `test` | `BuildTag` |
| `test` | `FunctionMarker` |
| `init`, `deinit` | `MethodDecl` (by name), `ForeignInitDecl` |
| `framework`, `module` | `DeclareDecl` |
| `blocks`, `threads` | `LaunchConfig` |
| `Expected`, `error` | `ExpectedType` |

`test` is the one name in two roles; the two positions never overlap.

### Predeclared type names

```
int      int8     int16    int32    int64
uint     uint8    uint16   uint32   uint64
byte     float32  float64  bool     char     string
```

These are ordinary identifiers pre-bound in an implicit outermost scope. A scanner does
not recognize them.

### Predeclared tensor element type names

```
bf16     fp8e4m3  fp8e5m2  int4
```

Ordinary identifiers in the same implicit scope. They are legal only as the
`ElementType` of a `TensorType` inside an `npu` body, and as a cast target there
(`bf16(val)`); everywhere else they parse and are rejected. They are body-only:
`accel.md` §2.2 forbids them in a signature.

### Predeclared constraint names

```
any      comparable
```

Ordinary identifiers in the same implicit scope. They are legal only in a `"["`…`"]"`
position — as a `TypeSetTerm` or a `ConstraintExpr` — never as a `Type`. A bare
`TypeParamName` is constrained by `any`.

### Reserved builtin names

```
new      delete   resize   copy     zero     addr     sizeof   alignof
reinterpret       upgrade  drop     panic    blend    min      max      clamp
transfer
```

These are ordinary identifiers, pre-bound in the same implicit scope, that may not be
shadowed or declared as a member, method, field, local, or parameter. Recognizing
`sizeof`, `alignof`, and `reinterpret` by name in `TypeOperatorCall` is sound only
because of that guarantee.

`transfer` is reserved and bound to nothing: it exists so that `x.transfer()` and
`transfer(x)` diagnose as "transfer is the `var` call-site marker" rather than as an
unknown name.

`unique`, `shared`, and `weak` are **keywords**, not reserved builtin names; they get
the `HeapConstructor` production.

### Operators and punctuation

```
(    )    [    ]    {    }    ,    .    ..   ...  :    ->
=    +=   -=   *=   /=   %=   &=   |=   ^=   <<=  >>=
+    -    *    /    %    ~    &    |    ^    <<   >>
&+   &-   &*
==   !=   <    >    <=   >=   ===  !==
&&   ||   !
```

The longest matching operator wins.

### Integer literals

An optional prefix sets a non-decimal base: `0b` or `0B` for binary, `0o` or `0O` for
octal, `0x` or `0X` for hexadecimal. There is no prefix-free octal form: `0600` is the
decimal integer 600.

For readability, `"_"` may appear between successive digits. It may not lead a digit
run, trail one, or be doubled.

```
int_lit        = decimal_lit | binary_lit | octal_lit | hex_lit .
decimal_lit    = decimal_digits .
binary_lit     = "0" ( "b" | "B" ) binary_digits .
octal_lit      = "0" ( "o" | "O" ) octal_digits .
hex_lit        = "0" ( "x" | "X" ) hex_digits .

decimal_digits = decimal_digit { [ "_" ] decimal_digit } .
binary_digits  = binary_digit  { [ "_" ] binary_digit } .
octal_digits   = octal_digit   { [ "_" ] octal_digit } .
hex_digits     = hex_digit     { [ "_" ] hex_digit } .
```

```
42
1_000
0b1010
0o600
0xBadFace
0x_67_7a     // invalid: "_" may not lead a digit run
42_          // invalid: "_" may not trail a digit run
4__2         // invalid: "_" may not be doubled
123abc       // invalid: identifier characters may not follow a numeric literal
```

There is no literal syntax for a negative number. `-1000` is unary minus applied to
`1000`.

### Floating-point literals

A decimal floating-point literal has an integer part, and either a fractional part or an
exponent part or both. **The fractional part, if a decimal point is written, must be
non-empty**; `1.` is not a literal, which is what makes `1..5` scan as
`int_lit ".." int_lit`. There is no leading-dot form: `.25` is not a literal.

A hexadecimal floating-point literal **requires** its binary exponent.

```
float_lit         = decimal_digits "." decimal_digits [ decimal_exponent ]
                  | decimal_digits decimal_exponent
                  | hex_float_lit .
decimal_exponent  = ( "e" | "E" ) [ "+" | "-" ] decimal_digits .

hex_float_lit     = "0" ( "x" | "X" ) hex_digits [ "." [ hex_digits ] ] hex_exponent .
hex_exponent      = ( "p" | "P" ) [ "+" | "-" ] decimal_digits .
```

```
1.5
1e9
6.674_28e-11
0x1.8p3
1.           // not a literal: fractional part is empty
.25          // not a literal: no leading-dot form
0xC.3        // invalid: hexadecimal float requires a binary exponent
```

### Numeric literals after a selector dot

The longest-token rule has exactly one restriction, and this is it.

**Rule.** A `float_lit` may not begin at a position immediately preceded by a `"."`
token whose own immediately preceding token is an `identifier`, `")"`, `"]"`, `"}"`,
`int_lit`, `float_lit`, or `string_lit`. Where the restriction applies, the scanner
produces an `int_lit` instead and the `"."` inside the would-be float is scanned as a
separate `"."` token.

This is what makes a positional-access chain scan. Without it, `t.0.0` scans as
`t` `.` `0.0` and `TupleIndex` never matches:

```
t.0.0        // t . 0 . 0    — four tokens after `t`, two TupleIndex chains
(t.0).0      // same meaning, no restriction needed
1.5          // unaffected: preceding token is not a "."
f(x).5       // int_lit 5 — a TupleIndex, not a float
```

The three members of this family — `1..5`, `.25`, and `t.0.0` — are now all handled: the
first two by the shape of `float_lit`, the third by this rule.

### Character literals

A character literal denotes exactly one Unicode scalar value.

```
char_lit   = "'" ( char_value | escape_seq ) "'" .
char_value = /* any unicode_char except "'" or "\" */ .
```

```
'A'
'\n'
'\u{1F600}'
'ab'         // invalid: more than one scalar value
''           // invalid: empty
'\u{D800}'   // invalid: a surrogate is a code point but not a scalar value
```

### String literals

There are two forms. An *interpreted* string literal is delimited by double quotes and
recognizes escape sequences; a line terminator may not appear in one. A *raw* string
literal is delimited by back quotes, recognizes no escape sequence, and every line
terminator it spans is part of its value.

```
string_lit             = interpreted_string_lit | raw_string_lit .
interpreted_string_lit = `"` { string_value | escape_seq } `"` .
string_value           = /* any unicode_char except `"` or "\" */ .
raw_string_lit         = "`" { /* any code point except "`" */ } "`" .
```

`char_value` and `string_value` are separate: a `"` is legal unescaped inside a
character literal and a `'` is legal unescaped inside a string literal.

A string is UTF-8 bytes with a length and no NUL terminator.

### Escape sequences

```
escape_seq        = "\" ( single_escape | hex_escape | unicode_escape ) .
single_escape     = "'" | `"` | "\" | "n" | "r" | "t" | "v" | "b" | "f" | "0" .
hex_escape        = "x" hex_digit hex_digit .
unicode_escape    = "u" "{" hex_digits "}" .
```

`unicode_escape` must denote a Unicode scalar value: not above `10FFFF`, and not a
surrogate.

---

## Source file

```
SourceFile    = [ terminator ] PackageClause [ BuildClause ] { ImportDecl }
                { TopLevelDecl terminator } .

PackageClause = "package" PackageName terminator .
PackageName   = identifier .

BuildClause   = "build" BuildTag terminator .
BuildTag      = "linux" | "windows" | "darwin" | "js" | "wasm" | "test" .
```

A file may open with blank or comment-only lines. The package clause is the first
non-comment construct and is mandatory. The build clause, if present, is the second;
`"build"` is meaningful only in that position. An unrecognized `BuildTag` is a compile
error, never a silently excluded file. Implementations may recognize additional tags.

```
ImportDecl = "import" ( ImportPath | "(" { ImportPath } ")" ) terminator .
ImportPath = string_lit .
```

There is no aliasing form, no dot-import, and no blank import. The qualifier under which
an imported package's symbols are reached comes from that package's own `PackageClause`;
the path is a locator, not a name. All imports precede all declarations.

```
TopLevelDecl = FunctionDecl | MethodDecl   | StructDecl | ClassDecl
             | EnumDecl     | TypeAliasDecl | ConstraintDecl
             | DeclareDecl  | VarDecl .
```

Top-level declarations are order-independent. A top-level `VarDecl`'s initializer must be
compile-time-evaluable, and the bare `"var" Binding` form is rejected there.

---

## Types

```
Type           = TypeName [ TypeArgs ] | TypeLit | "(" Type ")" .
TypeName       = identifier | QualifiedIdent .
QualifiedIdent = PackageName "." identifier .

TypeArgs       = "[" TypeList [ "," ] "]" .
TypeList       = Type { "," Type } .

TypeLit        = OwnershipType | ArrayType | SliceType   | MapType    | TupleType
               | FunctionType  | ChanType  | PointerType | TensorType | VectorType .
```

A parenthesized single type is that type. Predeclared type names arrive as ordinary
identifiers and match `TypeName`.

### Ownership-qualified types

```
OwnershipType = ( "mut" | "var" | "unique" | "shared" | "weak" ) Type .
```

Qualifiers do not stack; the recursion is unguarded so that a stacked form parses and can
be diagnosed as itself. `mut T` and `var T` are legal only in parameter and receiver
position. `unique T`, `shared T`, and `weak T` are ordinary types.

### Array, slice, and map types

```
ArrayType   = "[" ArrayLength "]" ElementType .
ArrayLength = Expression .
SliceType   = "[" "]" ElementType .
MapType     = "map" "[" KeyType "]" ElementType .
KeyType     = Type .
ElementType = Type .
```

`ArrayLength`, `KeyType`, `ElementType`, and `BaseType` are deliberate documentary
aliases for `Expression` / `Type`; they name the role a position plays.

### Tuple types

```
TupleType = "(" TupleElem { "," TupleElem } [ "," ] ")" .
TupleElem = [ identifier ":" ] Type .
```

A tuple has at least one element; there is no unit type. A parenthesized single type
without a trailing comma is the `"(" Type ")"` alternative of `Type`, so a one-element
tuple type requires its trailing comma.

### Function types and signatures

```
FunctionType  = "func" Signature .

Signature     = Parameters { FunctionMarker } [ Result ] .
DeclSignature = Parameters { FunctionMarker } [ DeclResult ] .

Parameters    = "(" [ ParameterList [ "," ] ] ")" .
ParameterList = ParameterDecl { "," ParameterDecl } .
ParameterDecl = [ identifier ":" ] [ "..." ] Type .

Result        = "->" Type .
DeclResult    = "->" ( Type | ExpectedType ) .

FunctionMarker = "async" | "gpu" | "npu" | "test" .
```

`Signature` is used by every construct that names a function *shape*: `FunctionType`,
`FunctionLit`, `MethodRequirement`, `ForeignFuncDecl`. `DeclSignature` is used only by
`FunctionDecl` and `MethodDecl`, and differs in exactly one way: an `ExpectedType` result
is admissible only there. That is what keeps
`var f: func() -> Expected(int32, "5")` out of the language syntactically.

A signature carries **at most one** `FunctionMarker`; the repetition is written so that
more than one parses and is rejected.

Within a `Parameters` list, the names must either all be present or all be absent. A bare
`FunctionType` names parameter types only; names belong to declarations, not to types. A
variadic parameter must be last and there may be at most one. Omitting the result is the
void form: there is no `void` type name.

The marker is part of a function's type, checked at both the declaration and the launch
site. Because `MethodRequirement` takes a full `Signature`, a constraint can require a
marked method:

```vertex
constraint Reader {
    func read(buf: mut []uint8) async -> (int32, string)
}
```

### Channel and pointer types

```
ChanType    = "chan" ElementType .
PointerType = "typed_ptr" BaseType .
BaseType    = Type .
```

A channel type carries no direction. A `PointerType` may not be the direct `BaseType` of
another; parenthesize the inner one.

### Tensor and vector types

```
TensorType = "tensor" "[" ElementType "," ShapeList "]" .
ShapeList  = int_lit { "," int_lit } .

VectorType = "vector" "[" ElementType "," int_lit "]" .
```

A `TensorType` is legal only inside an `npu`-marked function body or that function's own
signature; elsewhere it parses and is rejected. A `VectorType` is legal wherever a `Type`
is; where it may actually appear is a static rule.

### Abstract types

```
AbstractType = "abstract" .
```

Legal only as the target of a `TypeAliasDecl`.

---

## Expressions

```
Expression     = CastExpr | Expression binary_op Expression .
ExpressionList = Expression { "," Expression } .

CastExpr       = UnaryExpr { "as" Type } .

UnaryExpr      = PrimaryExpr
               | unary_op UnaryExpr
               | "await" UnaryExpr
               | "var" UnaryExpr .

unary_op       = "-" | "!" | "~" .
```

The `Expression` production is ambiguous as written and is disambiguated entirely by the
precedence table below.

`"var"` in expression position is the ownership marker. Its operand is written as a full
`UnaryExpr` so that `var f(a)` parses and can be diagnosed as a transfer of a computed
value rather than as a syntax error. **The operand must be a binding or a field path**
— informally

```
TransferTarget = identifier { "." identifier } .
```

— but that is a static rule, not a production, and `TransferTarget` appears nowhere in
the grammar. Index paths are excluded: `var items[0]` parses and is rejected. This is the
one form of `var`-in-expression there is; there is no second, competing production for it.

`"await"` parses unconditionally. Whether the enclosing body licenses it is a static rule.

### Operators

```
binary_op = "||" | "&&" | rel_op | ".." | add_op | mul_op | shift_op .

rel_op    = "==" | "!=" | "<" | "<=" | ">" | ">=" | "===" | "!==" .
add_op    = "+" | "-" | "|" | "^" | "&+" | "&-" .
mul_op    = "*" | "/" | "%" | "&" | "&*" .
shift_op  = "<<" | ">>" .
```

### Operator precedence

Binary operators bind left-to-right at **seven** levels below `as`, listed weakest first:

```
Precedence    Operators
    1         ||
    2         &&
    3         ==  !=  <  <=  >  >=  ===  !==
    4         ..
    5         +   -   |  ^   &+  &-
    6         *   /   %  &   &*
    7         <<  >>
```

`as` binds tighter than every binary operator and is left-associative:
`x as int32 as int64` is two conversions. Its right operand is a `Type`, not an
`Expression`, which is why it is written as `CastExpr` rather than as a `binary_op`.

`".."` is **non-associative**. `a..b..c` is a compile error; it is neither folded left nor
right.

### Primary expressions

```
PrimaryExpr    = PointerPrimary
               | LaunchExpr
               | PrimaryExpr Selector
               | PrimaryExpr TupleIndex
               | PrimaryExpr Index
               | PrimaryExpr Arguments .

PointerPrimary = Operand | "&" PointerPrimary .

Selector       = "." identifier .
TupleIndex     = "." int_lit .
Index          = "[" Expression "]" .
Arguments      = "(" [ ArgumentList [ "," ] ] ")" .
```

`"&"` binds tighter than `"."`: `&p.add(1)` is `(&p).add(1)`. Write `&(p.add(1))` for a
dereferenced read.

`"&"` is address-of on a value and dereference on a `typed_ptr`, read from the operand's
statically written type. `"~"` is bitwise-NOT in an expression and underlying-type in a
`TypeSetTerm`. Neither is distinguished syntactically.

An `Index` whose operand denotes a generic declaration is a `TypeArgs` list; otherwise it
is an index. Resolution is by what the operand denotes, not by shape. A slice is written
`a[low..high]` — an `Index` whose `Expression` is a range — so there is no separate slice
production.

A `"."` immediately followed by a digit is always positional tuple access; see *Numeric
literals after a selector dot*. `TupleIndex`'s `int_lit` must be a `decimal_lit`
containing no `"_"` — a static rule, since `int_lit` is the token the scanner produces.
Chains compose: `t.0.0`.

### Operands

```
Operand       = Literal
              | OperandName [ TypeArgs ]
              | NamespaceName
              | "(" Expression ")"
              | EnumShorthand
              | TypeOperatorCall
              | VectorCall
              | ChanConstructor
              | HeapConstructor .

OperandName   = identifier | QualifiedIdent .
NamespaceName = "async" | "gpu" | "npu" .

Literal       = BasicLit | CompositeLit | MapLit | ArrayLit | TupleLit | FunctionLit .
BasicLit      = int_lit | float_lit | char_lit | string_lit | "true" | "false" | "nil" .
```

A `NamespaceName` appears only as the operand of a `Selector`. `chan` is not one: it has
its own production (below), so no prose exception is needed.

`"(" Expression ")"` and `TupleLit` both open with `"("`; they are distinguished by the
comma, which a one-element tuple must therefore write.

### Composite, map, tuple, and array literals

```
CompositeLit   = LiteralType LiteralValue .
LiteralType    = TypeName [ TypeArgs ] .
LiteralValue   = "{" [ FieldValueList [ "," ] ] "}" .
FieldValueList = FieldValue { "," FieldValue } .
FieldValue     = identifier ":" OwningExpr .

MapLit         = "{" [ KeyValueList [ "," ] ] "}" .
KeyValueList   = KeyValue { "," KeyValue } .
KeyValue       = Expression ":" OwningExpr .

ArrayLit       = "[" [ ElementList [ "," ] ] "]" .
ElementList    = OwningExpr { "," OwningExpr } .

TupleLit           = "(" TupleElemValue "," [ TupleElemValueList [ "," ] ] ")" .
TupleElemValueList = TupleElemValue { "," TupleElemValue } .
TupleElemValue     = [ identifier ":" ] OwningExpr .
```

A composite literal's keys are field names; a map literal's keys are arbitrary
expressions. A composite literal constructs a struct; a class is constructed by calling an
initializer.

`(x)` is a parenthesized expression; `(x,)` is a one-element tuple.

**A parsing ambiguity arises** when a `CompositeLit` or `MapLit` appears as an operand
between the keyword and the opening brace of an `IfStmt`, `WhileStmt`, `ForStmt`, or
`SwitchStmt` header, and is not enclosed in parentheses, brackets, or braces. In that case
the literal's opening brace is parsed as the one introducing the block. To resolve,
parenthesize the literal:

```vertex
if p == (Point{x: 1}) { … }
```

The same ambiguity is why `ExprStmt` excludes a bare `CompositeLit` or `MapLit`.

### Function literals

```
FunctionLit = "func" Signature Block .
```

A function literal begins with all enclosing parse context cleared and re-establishes it
from its own `FunctionMarker`.

### Enum shorthand

```
EnumShorthand = "." identifier [ Arguments ] .
```

Legal only where the enum type is fixed by context. In `Pattern` position a leading `"."`
is never an `EnumShorthand`; see *Switch*.

### Type-operator and constructor calls

These are the only call forms taking a `Type` in argument position. Every other builtin is
an ordinary call.

```
TypeOperatorCall = "sizeof" "(" Type ")"
                 | "alignof" "(" Type ")"
                 | "reinterpret" "(" Type "," Expression ")" .

VectorCall       = VectorType "(" Expression [ "," Expression ] ")" .

ChanConstructor  = "chan" "[" Type "]" "(" [ Expression ] ")" .

HeapConstructor  = ( "unique" | "shared" | "weak" ) "(" Expression ")" .
```

A `VectorCall`'s callee is a `VectorType`, not a bare `Type`, and it is never a
`PrimaryExpr` operand of `Arguments` — no ordinary call reading applies to it. Which of its
two forms applies, and what each means, is a static rule.

A `ChanConstructor` is the only expression form of `chan`; `ChanType` is the only type
form. The two never compete, because a type position admits no expression. Its optional
argument is the capacity.

A `HeapConstructor` is spelled with a keyword and so cannot be an ordinary call over a
reserved name.

### Launch expressions

```
LaunchExpr   = "thread" CallExpr
             | "async"  CallExpr
             | "gpu" [ LaunchConfig ] CallExpr
             | "npu"    CallExpr .

CallExpr     = PrimaryExpr Arguments .
LaunchConfig = "(" "blocks" ":" Expression "," "threads" ":" Expression ")" .
```

`CallExpr` intentionally repeats the `PrimaryExpr Arguments` alternative of `PrimaryExpr`.
It is a named restriction — "a call and nothing else" — used by `LaunchExpr`, `DeferStmt`,
and `ChannelOp`.

A launch prefix modifies scheduling only, never the callee's signature. `LaunchConfig` has
fixed arity and fixed names and is not a general argument list.

**A parsing ambiguity arises** between a launch prefix and a namespace reference, since
`async`, `gpu`, and `npu` are both. It is resolved by one token of lookahead: if the
keyword is immediately followed by `"."`, it is a `NamespaceName` and the construct is a
`Selector`; otherwise it is a launch prefix. So `npu Dot(a, b)` is a launch and
`npu.Dot(a, b)` is a namespace member call. `thread` is not a namespace and needs no
lookahead.

### Owning positions

```
OwningExpr     = Expression .
OwningExprList = OwningExpr { "," OwningExpr } .
```

`OwningExpr` is a documentary alias for `Expression`. It marks the six *owning positions*:
the right-hand side of a `VarDecl` or `AssignStmt`, an `Argument`, an element of a
tuple / array / map / composite literal, a returned expression, and the binding of a
consuming `for` loop. Owning-ness does not propagate into subexpressions.

The transfer marker itself is `UnaryExpr`'s `"var"` alternative and nothing else; there is
no separate owning-position production for it, so no text has two parses. That the marker
appears *outside* an owning position — `var w` as a statement, `if var w { }` — is a
static rule.

The presence of `"var"` is the entire difference between a move and a deep copy.

### Arguments

```
ArgumentList = Argument { "," Argument } .
Argument     = [ identifier ":" ] OwningExpr .
```

Arguments may be positional or named. Mixing is a static rule, so both shapes are one
production here.

---

## Statements

```
Statement     = Block       | VarDecl      | AssignStmt | ExprStmt
              | IfStmt      | WhileStmt    | ForStmt    | SwitchStmt
              | SelectStmt  | ReturnStmt   | DeferStmt
              | BreakStmt   | ContinueStmt | FallthroughStmt .

Block         = "{" StatementList "}" .
StatementList = [ terminator ] { Statement terminator } .
```

### Declarations in statement position

```
VarDecl     = ( "let" | "var" ) BindingList "=" OwningExprList
            | "var" Binding .

BindingList = Binding { "," Binding } .
Binding     = identifier [ ":" Type ] .
```

The second alternative covers all three initializer-free forms uniformly:

```vertex
var buf: [1024]uint8     // typed, uninitialized
var _: int32             // typed, discarded
var w                    // bare — see below
```

Statement-leading `"var"` is always a declaration. A bare `var w` as a statement — which
would otherwise read as a transfer marker outside an owning position — parses as
`"var" Binding`, so the diagnostic can say "transfer outside owning position" against a
real declaration node rather than reporting a syntax error.

`let` requires an initializer; `var` does not.

### Assignment

```
AssignStmt       = AssignTargetList "=" OwningExprList
                 | AssignTarget assign_op Expression .

AssignTargetList = AssignTarget { "," AssignTarget } .
AssignTarget     = PrimaryExpr .

assign_op        = "+=" | "-=" | "*=" | "/=" | "%="
                 | "&=" | "|=" | "^=" | "<<=" | ">>=" .
```

`AssignTarget` is a bare `PrimaryExpr`. Dereference-writes (`&p = 99`,
`&(p.add(3)) = 9`) already derive through `PointerPrimary`, and the blank identifier
`_` is an ordinary `identifier`; neither needs its own alternative. Which
`PrimaryExpr` shapes are assignable is a static rule.

The compound form takes exactly one target and one value. Assignment is a statement and
never an expression, so there is no `"="` inside any condition in this grammar.

### Expression statements

```
ExprStmt = Expression .
```

An `ExprStmt` may not be a bare `CompositeLit` or `MapLit`; see the ambiguity note above.

### Control flow

```
IfStmt    = "if" Expression Block [ "else" ( IfStmt | Block ) ] .
WhileStmt = "while" Expression Block .
ForStmt   = "for" IterationBinding "in" Expression Block .

IterationBinding = [ "mut" | "var" ] IterationName [ "," IterationName ] .
IterationName    = identifier .
```

An `IfStmt` has no initializer clause; the two-statement error-checking idiom is
intentional. `WhileStmt` is the only loop primitive. The `ForStmt` mode marker sits on the
binding rather than on the iterable, because what transfers is each element, one per
iteration.

The marker and the two-name form do not combine: `for mut i, n in nums` parses and is
rejected. `for f in var frames` also parses — the iterable is an `Expression`, and
`"var" UnaryExpr` is one — and is likewise rejected.

### Switch

```
SwitchStmt  = "switch" Expression "{" [ terminator ] { CaseClause } "}" .
CaseClause  = ( "case" PatternList | "default" ) ":" StatementList .
PatternList = Pattern { "," Pattern } .
Pattern     = EnumPattern | Expression .

EnumPattern        = "." identifier [ "(" PayloadBindingList ")" ] .
PayloadBindingList = PayloadBinding { "," PayloadBinding } .
PayloadBinding     = identifier .
```

At most one `"default"` clause.

**Leading-dot resolution.** In `Pattern` position a leading `"."` is **always** an
`EnumPattern`, never an `EnumShorthand` reached through `Expression`. The alternatives are
ordered above to say so. The distinction is semantic, not cosmetic: an `EnumPattern`'s
payload entries are binding names, not expressions, and are views into the payload rather
than copies.

### Select

```
SelectStmt   = "select" "{" [ terminator ] { SelectClause } "}" .
SelectClause = ( "case" ChannelCase | "default" ) ":" StatementList .

ChannelCase  = ChannelOp
             | AssignTargetList "=" ChannelOp
             | ( "let" | "var" ) BindingList "=" ChannelOp .

ChannelOp    = CallExpr | "await" CallExpr .
```

The third alternative lets a case introduce its own bindings, which is what every example
in `channels.md` and `async.md` actually wants:

```vertex
select {
case let n, err = await conn_ch.receive():
case let v = await compute_ch.receive():
}
```

Bindings introduced by a `ChannelCase` are scoped to that clause's `StatementList`. The
assignment form remains for pre-declared targets. Which calls are admissible in
`ChannelCase` position, and the rule that one `select` is entirely bare or entirely
awaited, are static rules.

### Jumps

```
ReturnStmt      = "return" [ OwningExprList ] .
DeferStmt       = "defer" CallExpr .
BreakStmt       = "break" .
ContinueStmt    = "continue" .
FallthroughStmt = "fallthrough" .
```

A multi-value return is a bare comma list, never parenthesized: parentheses construct a
tuple, bare commas unbuild one. `defer` takes a call and nothing else. There are no loop
labels.

---

## Declarations

### Functions and methods

```
FunctionDecl = "func" FunctionName [ TypeParameters ] DeclSignature Block .
FunctionName = identifier .

MethodDecl   = "func" Receiver MethodName [ TypeParameters ] DeclSignature Block .
MethodName   = identifier .

Receiver     = "(" identifier ":" ReceiverType ")" .
ReceiverType = [ "mut" | "var" | "shared" ] TypeName [ TypeParameters ] .
```

A `MethodDecl` **may not** declare its own `TypeParameters`; the slot exists so that
`func (b: Box[T]) convert[U](…)` parses and the diagnostic can point a caret at `[U]`
rather than reporting a syntax error. A `ReceiverType`'s `TypeParameters` list re-declares
the receiver type's existing names rather than introducing fresh ones; the list is parsed
on both so that either error can name the rule it broke.

A `MethodDecl` whose `MethodName` is `init` or `deinit` is an initializer or deinitializer
declaration. Those get no production of their own: `init` and `deinit` are contextual
keywords that are ordinary method names in a receiver declaration. Whether a given
`MethodDecl` is one is a question about its name and receiver.

### Structs and classes

```
StructDecl = "struct" identifier [ TypeParameters ] "{" [ terminator ] { FieldDecl terminator } "}" .
ClassDecl  = "class"  identifier [ TypeParameters ] "{" [ terminator ] { FieldDecl terminator } "}" .
FieldDecl  = identifier ":" Type [ "=" Expression ] .
```

A field list is newline-separated juxtaposition, not a comma list; the enclosing brace is
therefore terminator-significant. Two fields on one line do not parse.

A class is byte-for-byte identical in layout to a struct and differs only in its member and
method model. A `FieldDecl`'s default is evaluated at construction for any omitted field.

### Enums

```
EnumDecl         = "enum" identifier [ TypeParameters ] [ DiscriminantType ]
                   "{" [ VariantList [ "," ] ] "}" .
DiscriminantType = ":" TypeName .
VariantList      = Variant { "," Variant } .
Variant          = identifier [ "(" TypeList ")" ] [ "=" Expression ] .
```

A variant list is comma-separated, and an `EnumDecl` body is **not** terminator-significant
— that is what lets a variant list span lines. Both suffixes are accepted on any `Variant`
so that an explicit discriminant on a payload variant parses and can be diagnosed as
itself.

### Type aliases

```
TypeAliasDecl = "type" identifier [ TypeParameters ] "=" AliasTarget .
AliasTarget   = Type | AbstractType .
```

### Constraints

```
ConstraintDecl    = "constraint" identifier "{" [ terminator ] { ConstraintElem terminator } "}" .
ConstraintElem    = TypeSet | MethodRequirement .
MethodRequirement = "func" identifier Signature .
```

There are no interfaces. A constraint is its own declaration form and is legal only in a
`"["`…`"]"` position.

A `ConstraintElem` that is a single identifier parses as both a one-term `TypeSet` and a
constraint name; resolution is by what the name denotes. Multiple elements form an
intersection, one per line.

---

## Generics

```
TypeParameters = "[" TypeParamList [ "," ] "]" .
TypeParamList  = TypeParamDecl { "," TypeParamDecl } .
TypeParamDecl  = TypeParamName [ ":" TypeSet ] .
TypeParamName  = identifier .

TypeSet        = TypeSetTerm { "|" TypeSetTerm } .
TypeSetTerm    = Type | "~" Type .
```

A bare `TypeParamName` is constrained by `any`. A constraint written on one entry of a
group also applies to every immediately preceding unconstrained entry —
`[A, B: Number]` constrains both — but that distribution is performed over an
already-parsed list, not by the grammar, so a formatter can reproduce the written form.

`"~" Type` admits every type whose underlying type is `Type`; a bare `Type` admits only
that type exactly. `"~"` outside a `TypeSet` is an error.

---

## Declare blocks

```
DeclareDecl = "declare" ( "framework" | "module" ) [ VariantTag ] string_lit DeclareBody .

VariantTag  = "[" string_lit { "," string_lit } "]" .
DeclareBody = "{" [ terminator ] { DeclareMember terminator } "}" .

DeclareMember = ForeignFuncDecl | ForeignClassDecl | DeclareDecl .

ForeignFuncDecl  = "func" identifier Signature [ Block ] .
ForeignClassDecl = "class" identifier "{" [ terminator ] { ForeignClassMember terminator } "}" .

ForeignClassMember = ForeignFuncDecl | ForeignInitDecl | FieldDecl .
ForeignInitDecl    = "init" "func" [ identifier ] Parameters "->" TypeName .
```

`"framework"` and `"module"` are contextual keywords meaningful only immediately after
`"declare"`. The `VariantTag` is hoisted out of the `module` branch so that
`declare framework["windows","com"] "SomeLib"` parses and is rejected with a message about
`declare framework`, rather than as a syntax error. The tag set is closed; membership is a
static rule.

In `ForeignInitDecl`, `"init"` is a prefix modifier on `func`, not a function name. The
unnamed form is what bare `Type(...)` construction resolves to.

A declare block describes call shapes only. Each of the following parses and is rejected,
so the diagnostic can name the construct:

* a `Block` on a `ForeignFuncDecl`
* a `FieldDecl` in a `ForeignClassDecl`
* a nested `DeclareDecl`
* a `FunctionMarker` on a `ForeignFuncDecl`

There is no visibility-modifier token in Vertex, so no visibility form is mentioned here or
in the rejection appendix.

---

## Test result types

```
ExpectedType = "Expected" "(" TypeName "," string_lit ")"
             | "Expected" "(" "error" [ "," string_lit ] ")" .
```

`Expected` and `error` are ordinary identifiers; this production is the only place either
is recognized. An `ExpectedType` reaches the grammar only through `DeclResult`, so it can
appear only on a `FunctionDecl` or `MethodDecl`, never in a `FunctionType` or
`FunctionLit`. That it is further restricted to a file built under the `test` tag is a
static rule.