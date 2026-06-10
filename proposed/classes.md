# Proposed: Implicit Reference Types for Classes

## The Problem

Vertex classes are always heap-allocated. The lowerer maps every `VClass` to
`Ptr(struct)` without exception. Yet today nothing stops a developer writing:

```vs
func foo(arr: *Array) { ... }   // redundant star
func foo(arr: Array)  { ... }   // identical at runtime
```

The `*` adds visual noise and implies a meaningful distinction that does not exist.

## Proposal

Ban `*` on class types at the resolver level. Classes are always references.

```vs
// before
func process(buf: *Buffer) -> *Buffer { ... }

// after
func process(buf: Buffer) -> Buffer { ... }
```

Optional references already work cleanly:

```vs
var cache: Buffer?          // optional reference
weak var delegate: Buffer?  // weak reference (ARC)
```

## Rule

| Type        | Syntax       | Semantics              |
|-------------|--------------|------------------------|
| class       | `Foo`        | always a heap reference |
| class opt   | `Foo?`       | nullable reference      |
| class weak  | `weak Foo?`  | weak ARC reference      |
| struct      | `Bar`        | value, stack allocated  |
| struct ptr  | `*Bar`       | explicit pointer        |

`*ClassName` becomes a compile error with a clear message:
> *class types are always reference types — write `Buffer` not `*Buffer`*

## Why This Beats Go

Go requires explicit `*` on everything. Newcomers spend real time learning which
types need stars and which do not. In Vertex the rule is one sentence:

> **structs use stars, classes never do.**

Less syntax to learn, fewer bugs from forgetting a `*`, and code that reads
closer to plain English.