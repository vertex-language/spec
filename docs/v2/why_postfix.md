# Why Postfix

## The Short Version

Vertex uses postfix for operations that other languages express as free
functions, prefix keywords, or macro calls. The pattern isn't new — Rust
validated it for `await` after years of public debate — but Vertex extends
it uniformly across the entire language: execution, intrinsics, concurrency,
array operations, and result propagation.

---

## C: The Baseline

C established the model most systems languages inherited. Operations are free
functions or keywords that wrap the expression:

```c
sizeof(SockaddrIn)
strlen(s)
malloc(256)
```

This made sense in 1972. Functions were simple, types were flat, and the
compiler needed to own `sizeof` because it operates on the type, not a value.
But the model has a hard limit: **you cannot chain**.

```c
// C — read inside-out, allocation tracked manually
GArray *filtered = filter(items);
GArray *mapped   = map(filtered);
sort(mapped);
int n = mapped->len;
g_array_free(filtered, TRUE);
g_array_free(mapped, TRUE);
```

Execution order is right-to-left through nested calls, or split across
multiple assignment lines. The code doesn't read the way it runs.

---

## Go: Free Functions as a Pragmatic Choice

Go kept free functions for its most fundamental operations:

```go
n      := len(items)
items   = append(items, 42)
size   := unsafe.Sizeof(MyStruct{})
```

This was driven by a real constraint. Go slices are value types — a slice
header is a `(pointer, length, capacity)` struct. `append` may allocate a
new backing array and return a *new* header, which means the caller must
reassign:

```go
items = append(items, 42)   // reassign — old header may be stale
```

A method on the slice cannot return a new slice of the same type cleanly
without generics, which Go didn't have at launch. The free function was
the honest solution to a real problem.

The cost: **core operations aren't discoverable**. Typing `items.` surfaces
nothing. You learn the language by reading the spec, not by exploring the
type. Chaining also breaks naturally:

```go
// Go — free functions interrupt the chain
filtered := filter(items)
sort.Slice(filtered, func(i, j int) bool { return filtered[i] < filtered[j] })
n := len(filtered)
```

Go's choice was correct *for Go*. The constraints were real and the solution
was honest. But the constraints don't apply to every language.

---

## Rust: The Await Debate

Rust's postfix story is documented because the community argued about it
publicly for over a year. The original async proposal used a macro:

```rust
let user = await!(fetch_user(id));
```

Then a prefix keyword was proposed:

```rust
let user = await fetch_user(id);
```

The problem both forms share is what happens when combined with `?` — Rust's
error propagation operator (analogous to Vertex's `.try()`):

```rust
// prefix — nested, reads inside-out
let n = await (await fetch_connection())?.query("SELECT ...")?;
```

The team landed on postfix `.await` — a keyword in postfix position, without
parentheses:

```rust
// postfix — left to right, execution matches reading order
let n = fetch_connection().await?.query("SELECT ...").await?;
```

The Rust RFC explicitly cited **method chaining ergonomics** as the deciding
factor. The subject stays on the left, the operation follows on the right.
Each step applies to the result of the previous one. You read the code in
the same direction it runs.

One detail worth noting: Rust's `.await` is a postfix keyword, not a method
call — no parentheses. Vertex uses `.await()` with parens, treating it
consistently as a method call, because Vertex makes no syntactic distinction
between intrinsic and user-defined operations. Everything looks the same.

---

## Vertex: Extend It Uniformly

Vertex takes the conclusion Rust reached for `await` and treats it as a
first principle across the whole language — not a special case for async,
but the right shape for every operation that transforms or queries a value.

**Execution model — all postfix:**
```swift
kernel.dispatch()
work.spawn()
task.await()
process.fork()
result.try()
```

**Memory intrinsics — postfix on the type or instance:**
```swift
SockaddrIn.sizeof()     // type-level  — compile-time constant
SockaddrIn.alignof()    // type-level  — compile-time constant
vertices.byteSize()     // instance-level — length * stride
```

**Array operations — full postfix chain:**
```swift
let n = items
    .filter(func(x: int32) -> bool { return x > 0 })
    .map(func(x: int32) -> int32 { return x * 2 })
    .sort(func(a: int32, b: int32) -> int32 { return a - b })
    .length
```

The same pipeline across all four languages:

```c
// C — inside-out nesting, manual memory tracking
GArray *filtered = filter(items);
GArray *mapped   = map(filtered);
sort(mapped);
int32_t n = mapped->len;
g_array_free(filtered, TRUE);
g_array_free(mapped,   TRUE);
```

```go
// Go — linear but free functions break the chain
filtered := filter(items)
sort.Slice(filtered, cmp)
n := len(filtered)
```

```rust
// Rust — postfix for await and ?, iterator adapters for collections
let n = items.iter()
    .filter(|x| **x > 0)
    .map(|x| x * 2)
    .collect::<Vec<_>>()
    .len();
```

```swift
// Vertex — uniform postfix throughout
let n = items
    .filter(func(x: int32) -> bool { return x > 0 })
    .map(func(x: int32) -> int32 { return x * 2 })
    .length
```

---

## The sizeof Argument

`sizeof(T)` in C works. But it frames size as an external operation
performed *on* a type rather than a property *of* a type.

```c
sizeof(SockaddrIn)              // C  — operation wraps the type
unsafe.Sizeof(MyStruct{})       // Go  — requires a fake zero-value instance
std::mem::size_of::<SockaddrIn>() // Rust — namespace path, type parameter
```

```swift
SockaddrIn.sizeof()             // Vertex — size belongs to the type
SockaddrIn.alignof()
```

The postfix form reads as a query directed at the type: *what is your size?*
The prefix forms read as an operation that needs the type handed to it from
the outside. The difference is subtle but it compounds — every intrinsic,
every operation, every chain — into a consistent mental model or a
fragmented one.

---

## Why Vertex Doesn't Follow Go Here

Go's free function choices were correct for Go's constraints. Slice value
semantics, no generics at launch, and a deliberate preference for a small
language surface all pushed toward `len()` and `append()`. Those are
legitimate reasons.

Vertex doesn't share them. Arrays are heap-allocated GArrays mutated in
place — `.push()` never needs to return a new header. Generics exist from
day one. The language is already method-oriented. Adopting Go's free
function style would mean borrowing a workaround for a problem Vertex
doesn't have, at the cost of a consistent postfix model that the rest of
the language already commits to.

---

## Summary

| Language | Core array ops   | Async / execution     | Type intrinsics                    |
|----------|------------------|-----------------------|------------------------------------|
| C        | free functions   | N/A                   | `sizeof(T)` prefix                 |
| Go       | free builtins    | goroutine + channel   | `unsafe.Sizeof(T{})` free function |
| Rust     | method chains    | postfix `.await`      | `std::mem::size_of::<T>()`         |
| Vertex   | postfix methods  | postfix uniform       | `T.sizeof()` postfix               |

Rust proved the postfix position wins for async after a rigorous, public,
multi-year debate. Vertex treats that conclusion not as a special case but
as the right pattern for the entire language surface — execution, introspection,
collection operations, and result propagation alike.

The goal is a language where you write left to right, chain without
interruption, discover operations by typing `.`, and never have to remember
whether a given operation is a free function, a builtin, a keyword, or a
method. In Vertex, the answer is always the same: it's on the value, and
it's on the right.