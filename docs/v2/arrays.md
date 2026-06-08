## The Three Regions

```
┌─────────────────────────────────────────────────────┐
│  Static / .rodata / .bss                            │
│  - string literals ("hello")                        │
│  - compile-time constants                           │
│  - zero-initialized globals                         │
│  - lifetime: entire program                         │
│  - cost: zero at runtime                            │
├─────────────────────────────────────────────────────┤
│  Stack                                              │
│  - scalars  (int32, float64, bool)                  │
│  - fixed arrays  ([uint8](1024))                    │
│  - structs of the above                             │
│  - lifetime: scope exit (automatic)                 │
│  - cost: one pointer move                           │
├─────────────────────────────────────────────────────┤
│  Heap                                               │
│  - growable arrays  ([int32]())                     │
│  - mutable strings  (var s = "hello")               │
│  - hash tables                                      │
│  - lifetime: manual  (defer .delete())              │
│  - cost: malloc/realloc/free                        │
└─────────────────────────────────────────────────────┘
```

---

## Your ABI Already Encodes This

You made the decisions without realising it:

| Vertex construct | Region | Why |
|---|---|---|
| `let greeting = "hello"` | static `.rodata` | immutable, size known, lives forever |
| `let x: int32 = 42` | stack | fixed size, scope lifetime |
| `var buf = [uint8](1024)` | stack | fixed size known at compile time |
| `var name = "hello"` | heap | mutable, needs `g_string_free` |
| `var items = [int32]()` | heap | dynamic size, needs `free` |
| `var config = {"a": 1}` | heap | dynamic, needs `free` |

The rule your compiler already follows:

```
compile-time fixed size + scope lifetime  →  stack
runtime dynamic size OR extended lifetime →  heap
immutable + known at compile time         →  static
```

---

## Why You Can't Pick Just One

```
stack only  →  can't have growable arrays, dynamic strings, or anything
               whose size isn't known at compile time. You'd need to
               over-allocate everything upfront. No real programs fit.

heap only   →  malloc/free on every int32. Catastrophic for performance.
               Every scalar allocation is ~100x slower than stack.
               Cache thrashing. Fragmentation. This is why early Java
               boxing was slow.

static only →  no dynamic data at all. Embedded firmware sometimes does
               this, but it's not a general-purpose language anymore.
```

---

## The Decision Rule for Your Lowering Pass

```
Is size known at compile time?
    YES → Is it a string literal (let)?
              YES → static .rodata  (const char *)
              NO  → stack           (T name[N])
    NO  → heap                      (VArray *, malloc/realloc/free)
              always emit a defer .delete()
```


package arrays
import "linux/lib/c"

class C : c {
    func malloc(size: int32) -> *char
    func realloc(ptr: *char, size: int32) -> *char
    func free(ptr: *char)
    func memcpy(dst: *char, src: *const char, n: int32) -> *char
    func memset(dst: *char, val: int32, n: int32) -> *char
}

class Array<T> {
    data:   *char
    length: int32
    cap:    int32
}

func (a: *Array<T>) init() {
    var libc = C()
    a.data   = libc.malloc(8 * sizeOf<T>())
    a.length = 0
    a.cap    = 8
}

func (a: *Array<T>) deinit() {
    var libc = C()
    libc.free(a.data)
}

func (a: *Array<T>) push(val: T) {
    if a.length == a.cap {
        a.cap *= 2
        var libc = C()
        a.data = libc.realloc(a.data, a.cap * sizeOf<T>())
    }
    var libc  = C()
    var dest  = a.data + a.length * sizeOf<T>()
    libc.memcpy(dest, reinterpret<*const char>(&val), sizeOf<T>())
    a.length += 1
}

func (a: *Array<T>) pop() -> T? {
    if a.length == 0 { return nil }
    a.length -= 1
    return reinterpret<*T>(a.data + a.length * sizeOf<T>())[]
}


```vertex
// ── USER WRITES ──────────────────────────    // ── FRONTEND LOWERS TO ─────────────────────

var items = [int32]()                           var items = Array<int32>()
defer items.delete()                            defer items.delete()

var items = [int32](capacity: 64)              var items = Array<int32>(capacity: 64)
defer items.delete()                            defer items.delete()

items.push(42)                                  items.push(42)

let last = items.pop()                          let last = items.pop()

let n = items.length                            let n = items.length

let x = items[0]                               let x = items.get(0)

items[0] = 99                                   items.set(0, 99)

for n in items { }                              var _i = 0
                                                while _i < items.length {
                                                    let n = items.get(_i)
                                                    _i += 1
                                                }

var doubled = items.map(                        var doubled = items.map(
    func(x: int32) -> int32 {                      func(x: int32) -> int32 {
        return x * 2                                    return x * 2
    })                                             })
defer doubled.delete()                          defer doubled.delete()

let idx = items.indexOf(42)                     let idx = items.indexOf(42)
let has = items.includes(42)                    let has = items.includes(42)
```

---

The only real sugar is three things:

```
[int32]()     →   Array<int32>()          // construction syntax
items[0]      →   items.get(0)            // subscript read
items[0] = 99 →   items.set(0, 99)        // subscript write
for n in items →  while loop + .get(_i)  // iteration
```



Looking through `lowerer.go`, `vtypes.go`, and `resolver.go`, here's exactly where classes stand.

## What Currently Works

Tracing through the code, a class lowers like this:

**Vertex**
```vertex
class Animal {
    name: string
    age:  int32
}

func (a: *Animal) init(name: string, age: int32) {
    a.name = name
    a.age  = age
}

func (a: *Animal) deinit() { }

func (a: *Animal) speak() {
    libc.printf("%s\n", a.name)
}

func main() -> int {
    let a = Animal(name: "Rex", age: 3)
    defer a.delete()
    a.speak()
    return 0
}
```

**What ir/c emits right now**
```c
typedef struct {
    const char *name;   // ← string field, immutable path
    int32_t     age;
} main_Animal;

void main_Animal__init(main_Animal *a, const char *name, int32_t age) {
    a->name = name;
    a->age  = age;
}

void main_Animal__deinit(main_Animal *a) { }

void main_Animal__speak(main_Animal *a) {
    printf("%s\n", a->name);
}

int32_t main(void) {
    main_Animal *_t1 = (main_Animal *)malloc(sizeof(main_Animal));
    main_Animal__init(_t1, "Rex", 3);   // ← from lowerClassInstantiate
    main_Animal__speak(_t1);
    main_Animal__deinit(_t1);           // ← from lowerClassMethod "delete"
    free(_t1);
    return 0;
}
```

---

## What's Missing / Broken Right Now

Looking directly at the code:

**`.new()` ref counting — stub only**
```go
// lowerClassMethod in lowerer.go
case "new":
    return recv   // ← just hands back the pointer, no ref count struct at all
```

**`weak let` — not wired**  
The AST has `IsWeak` on `VarDecl` but the lowerer never reads it anywhere.

**Mutable string fields in classes** — the `VString.Mutable` flag is set during `resolveLocalDecl` based on `let`/`var`, but class fields have no `let`/`var` — they're declared as bare `name: type`. So `resolvedFieldCIRType` always produces `const char *` for string fields, even ones you intend to mutate.

---

## The Class → C Pipeline (the three paths)

```
Animal(name: "Rex")      →  malloc + __init call    (lowerClassInstantiate)
a.speak()                →  main_Animal__speak(a)   (lowerClassMethod)  
a.delete()               →  __deinit(a) + free(a)   (lowerClassMethod "delete")
a.name                   →  a->name                 (lowerFieldExpr VClass branch)
```

The heap allocation path is correct. The name mangling (`pkg_Type__method`) is correct. Field access via `->` is correct.

The two things to fix before arrays make sense are the string field mutability and the `.new()` stub — everything else in the class path is functional.