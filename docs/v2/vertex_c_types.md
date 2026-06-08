# Vertex ↔ C Types

---

## Design Rationale

Vertex uses `*` for pointer types, consistent with every major systems language:
C, C++, Go, Rust, and Carbon. The pointer sigil was never the real pain point —
developers across all those languages adapted to it without issue.

What was actually painful in C and C++ was repetition — writing `*` over and
over in declarations, signatures, and parameters. C++ eventually addressed this
with the `auto` keyword, reducing how often you had to spell out pointer types
explicitly. Vertex solves the same problem differently: `let` and `var` with
type inference mean you rarely write `*T` in everyday code at all:

```vertex
let p    = &x        // inferred *int32 — no annotation needed
let file = fopen()   // inferred FILE?  — no annotation needed
```

`*T` is explicit only where it needs to be: extern declarations, function
signatures, and struct fields.

The real improvements over C and C++ are:

- `let` / `var` — mutability as a first-class concept, not a `const` afterthought
- `*T?` vs `*T` — null safety enforced by the type system, not convention
- `*const T` — cleaner than C's confusing const placement rules

---

## Scalars

| Vertex                | C             |
|-----------------------|---------------|
| `int8`                | `int8_t`      |
| `int16`               | `int16_t`     |
| `int32` / `int`       | `int32_t`     |
| `int64`               | `int64_t`     |
| `uint8`               | `uint8_t`     |
| `uint16`              | `uint16_t`    |
| `uint32` / `uint`     | `uint32_t`    |
| `uint64`              | `uint64_t`    |
| `float32` / `float`   | `float`       |
| `float64`             | `double`      |
| `bool`                | `bool`        |
| `char`                | `char`        |
| `void` / `()`         | `void`        |

---

## Bindings

| Vertex             | C                      |
|--------------------|------------------------|
| `let x: int32 = 1` | `const int32_t x = 1;` |
| `var x: int32 = 1` | `int32_t x = 1;`       |

`let` → `const`. `var` → mutable. Both are stack values — no pointer, no heap.

---

## Pointers — `*`

`*` in type position is a raw mutable pointer. `*const` is a raw read-only
pointer. These are the only pointer types in Vertex.

| Vertex                  | C                   |
|-------------------------|---------------------|
| `name: *T`              | `T*`                |
| `name: *const T`        | `const T*`          |
| `name: *void`           | `void*`             |
| `name: *const void`     | `const void*`       |
| `name: *char`           | `char*`             |
| `name: *const char`     | `const char*`       |
| `name: *T?`             | `T*` nullable       |
| `name: *const T?`       | `const T*` nullable |
| `name: **T`             | `T**`               |

`&name` at the call site returns the address of a value. Zero cost, no copy.

`let`/`var` controls whether the binding can be rebound.
`*const` controls whether the pointed-to data can be modified.
These are orthogonal — all four combinations are valid.

| Vertex               | C                | Binding | Data      |
|----------------------|------------------|---------|-----------|
| `let name: *const T` | `const T* const` | fixed   | read-only |
| `let name: *T`       | `T* const`       | fixed   | mutable   |
| `var name: *const T` | `const T*`       | rebind  | read-only |
| `var name: *T`       | `T*`             | rebind  | mutable   |

---

## Parameters — Explicit Pointers

No inout convention. Pointer parameters are explicit. Caller passes address
with `&`.

| Vertex                     | C                    |
|----------------------------|----------------------|
| `func f(n: *int32)`        | `void f(int32_t *n)` |
| `f(n: &count)` ← call site | `f(&count)`          |

---

## Strings

| Vertex            | C                                                   |
|-------------------|-----------------------------------------------------|
| `let s = "hello"` | `const char *s = "hello";`  (.rodata)               |
| `var s = "hello"` | `strings_String s = strings_new("hello");`  (heap)  |

---

## Arrays — Fixed

| Vertex                          | C                                         |
|---------------------------------|-------------------------------------------|
| `var buf = [uint8](1024)`       | `uint8_t buf[1024]; memset(buf,0,1024);`  |
| `let f: [uint8] = [0xFF, 0x00]` | `const uint8_t f[2] = { 0xFF, 0x00 };`   |

Stack allocated. Size is a compile-time constant. No `.delete()` needed.

---

## Arrays — Dynamic

| Vertex                          | C                                               |
|---------------------------------|-------------------------------------------------|
| `var a = [int32]()`             | `arrays_Array a = arrays_new(sizeof(int32_t));` |
| `var a = [int32](capacity: 64)` | `arrays_Array a = arrays_new_cap(4, 64);`       |

Backed by `builtin/arrays`:
```c
typedef struct {
    uint8_t  *data;
    uint64_t  len;
    uint64_t  cap;
    uint64_t  stride;
} arrays_Array;
```

---

## Structs

Value type. Assignment copies. Stack by default. No heap.

```
Vertex                               C
──────────────────────────────────────────────────────────────
struct Point { x: int32; y: int32 }  typedef struct {
                                         int32_t x;
                                         int32_t y;
                                     } Point;

let p = Point{x: 1, y: 2}           const Point p = { .x=1, .y=2 };
var q = Point{x: 1, y: 2}           Point q = { .x=1, .y=2 };
```

---

## Classes

Heap allocated. `init`/`deinit` lower to free functions with pointer receiver.

```
Vertex                               C
──────────────────────────────────────────────────────────────
class Animal { name: string }        typedef struct {
                                         const char *name;
                                     } Animal;

let a = Animal(name: "Rex")          Animal *a = malloc(sizeof(Animal));
                                     Animal__init(a, "Rex");

a.delete()                           Animal__deinit(a); free(a);
```

---

## Classes — Reference Counted `.new()`

`ref_count` injected into struct layout by the Lowerer.

```
Vertex                                C
──────────────────────────────────────────────────────────────
let a = Animal(name: "Rex").new()     typedef struct {
                                          int32_t     ref_count;  ← injected
                                          const char *name;
                                      } Animal;

let b = a           // count = 2      Animal__retain(a);
// b out of scope   // count = 1      Animal__release(b);
// a out of scope   // count = 0      Animal__release(a); → deinit + free
```

---

## Optionals

| Vertex    | C                                           |
|-----------|---------------------------------------------|
| `Animal?` | `Animal *` — nullable pointer               |
| `int32?`  | `struct { int32_t value; bool has_value; }`  |

Pointer/class optionals → nullable pointer. Scalar optionals → tagged struct.

---

## Result

```
Vertex                        C
──────────────────────────────────────────────────────────────
Result(int32, string)         typedef struct {
                                  enum { RESULT_OK, RESULT_ERR } tag;
                                  union {
                                      int32_t     ok;
                                      const char *err;
                                  };
                              } Result_int32_string;
```

---

## Tuples

```
Vertex                        C
──────────────────────────────────────────────────────────────
(int32, bool)                 typedef struct { int32_t _0; bool _1; } ...;
(x: int32, y: int32)          typedef struct { int32_t x; int32_t y; } ...;
```

---

## Enums

```
Vertex                        C
──────────────────────────────────────────────────────────────
enum Dir {                    typedef enum {
    case n, s, e, w               Dir_n, Dir_s, Dir_e, Dir_w
}                             } Dir;

enum Status: int {            typedef enum {
    case off = 0                  Status_off = 0,
    case on  = 1                  Status_on  = 1,
}                             } Status;
```

---

## Function Types

| Vertex                        | C                                  |
|-------------------------------|------------------------------------|
| `func(int32) -> bool`         | `bool (*fn)(int32_t)`              |
| `func(int32, int32) -> int32` | `int32_t (*fn)(int32_t, int32_t)`  |

Closures with captures lower to an environment struct + trampoline.

---

## Type Aliases

| Vertex                 | C                       |
|------------------------|-------------------------|
| `type FILE = *void`    | `typedef void* FILE;`   |
| `type size_t = uint64` | `typedef uint64_t size_t;` |

---

## Extern Declarations

C library functions are declared with `extern`. No body, no implementation.

```swift
// --- extern declarations ---

extern func fopen(
    path: *const char,
    mode: *const char
) -> FILE?

extern func fclose(
    stream: FILE
) -> int32

extern func fwrite(
    ptr:    *const void,
    size:   uint64,
    nmemb:  uint64,
    stream: FILE
) -> uint64

extern func fread(
    ptr:    *void,
    size:   uint64,
    nmemb:  uint64,
    stream: FILE
) -> uint64

// --- usage ---

func write_file(path: *const char, data: *const void, len: uint64) -> bool {
    let file = fopen(path, "w")
    if file == nil { return false }

    let written = fwrite(data, 1, len, file)

    fclose(file)
    return written == len
}



// --- opaque C handles, same pattern as FILE ---
type SDL_Window   = *void
type SDL_Renderer = *void

// --- SDL_Event is a C union; we only need .type,
//     but the struct must be 56 bytes to match the ABI ---
struct SDL_Event {
    type: uint32
    _p0:  uint32   // align to 8
    _p1:  uint64
    _p2:  uint64
    _p3:  uint64
    _p4:  uint64
    _p5:  uint64
    _p6:  uint64
}

// --- extern declarations ---
extern func SDL_Init(flags: uint32) -> int32
extern func SDL_Quit()

extern func SDL_CreateWindow(
    title: *const char,
    x:     int32,
    y:     int32,
    w:     int32,
    h:     int32,
    flags: uint32
) -> SDL_Window?

extern func SDL_DestroyWindow(window: SDL_Window)

extern func SDL_CreateRenderer(
    window: SDL_Window,
    index:  int32,
    flags:  uint32
) -> SDL_Renderer?

extern func SDL_DestroyRenderer(renderer: SDL_Renderer)

extern func SDL_SetRenderDrawColor(
    renderer: SDL_Renderer,
    r: uint8, g: uint8, b: uint8, a: uint8
) -> int32

extern func SDL_RenderClear(renderer: SDL_Renderer)   -> int32
extern func SDL_RenderPresent(renderer: SDL_Renderer)
extern func SDL_PollEvent(event: *SDL_Event)          -> int32
extern func SDL_Delay(ms: uint32)

// --- constants ---
let SDL_INIT_VIDEO:           uint32 = 0x00000020
let SDL_WINDOWPOS_CENTERED:   int32  = 0x2FFF0000
let SDL_WINDOW_SHOWN:         uint32 = 0x00000004
let SDL_RENDERER_ACCELERATED: uint32 = 0x00000002
let SDL_QUIT:                 uint32 = 0x100

// --- entry point ---
func main() -> int32 {
    if SDL_Init(SDL_INIT_VIDEO) != 0 {
        return 1
    }

    let window = SDL_CreateWindow(
        "Hello SDL2",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        800, 600,
        SDL_WINDOW_SHOWN
    )
    if window == nil {
        SDL_Quit()
        return 1
    }

    let renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED)
    if renderer == nil {
        SDL_DestroyWindow(window)
        SDL_Quit()
        return 1
    }

    var running = true
    var event   = SDL_Event{}

    while running {
        while SDL_PollEvent(&event) != 0 {
            if event.type == SDL_QUIT {
                running = false
            }
        }

        SDL_SetRenderDrawColor(renderer, 30, 30, 46, 255)
        SDL_RenderClear(renderer)
        SDL_RenderPresent(renderer)
        SDL_Delay(16)
    }

    SDL_DestroyRenderer(renderer)
    SDL_DestroyWindow(window)
    SDL_Quit()
    return 0
}
```