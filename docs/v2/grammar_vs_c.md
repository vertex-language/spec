# Vertex ↔ C ABI Reference

## How Vertex lowers to C (GLib ABI)

Each section shows the Vertex surface syntax on the left and the exact C/GLib
code emitted by the lowering pass on the right. All GLib types require
`#include <glib.h>`; scalar sections need only `<stdint.h>`, `<stdbool.h>`,
`<string.h>`, and `<stdlib.h>`.

---

## 1. Variable Declarations


## 1.1 Literals

**Vertex**
```vertex
// Integers — decimal (default)
42
-1000
1_000_000       // underscore separator — ignored by compiler

// Integers — alternate bases
0b101010        // binary   (base 2)
0o52            // octal    (base 8)
0x2A            // hex      (base 16)

// Hex digits are case-insensitive
0xFF
0xBadFace
0x0123_4567_89ab_cdef   // underscores valid in any base

// Floats — decimal
3.14
1_000.000_1
1.25e2          // = 1.25 × 10²  = 125.0
1.25e-2         // = 1.25 × 10⁻² = 0.0125
1.25E2          // uppercase E — equivalent

// Floats — hex (binary exponent)
0xFp2           // = 15 × 2²  = 60.0
0xFp-2          // = 15 × 2⁻² = 3.75
0xC.3p0         // fractional hex mantissa

// Boolean
true
false

// Nil — absence of a value
nil

// Other literals (unchanged)
"hello"
"A"
```

**Vertex**
```vertex
let x = 42
var y = 20
let flag: bool = true
```

**C**
```c
const int32_t x    = 42;
int32_t       y    = 20;
const bool    flag = true;
```

**Rules**
- `let` → `const`; the value is immutable after initialisation.
- `var` → no qualifier; the value may be reassigned.
- Type is inferred; an explicit annotation becomes the C type directly.

---

## 2. Type Annotations

| Vertex type         | C type     |
|---------------------|------------|
| `int`               | `int32_t`  |
| `int8`              | `int8_t`   |
| `int16`             | `int16_t`  |
| `int32`             | `int32_t`  |
| `int64`             | `int64_t`  |
| `uint`              | `uint32_t` |
| `uint8`             | `uint8_t`  |
| `uint16`            | `uint16_t` |
| `uint32`            | `uint32_t` |
| `uint64`            | `uint64_t` |
| `float32`           | `float`    |
| `float64`           | `double`   |
| `bool`              | `bool`     |
| `string`            | see §7     |
| `char`              | `char`     |
| `void` / `()`       | `void`     |

---

## 3. Numeric Type Conversion

**Vertex**
```vertex
let i: int    = 42
let f: float32  = float32(i)       // widening — always safe
let d: float64 = float64(f)    // widening — always safe
let i2: int   = int(3.99)      // truncates toward zero → 3
let b: int8   = int8(i)        // narrowing — wraps on overflow
```

**C**
```c
const int32_t i  = 42;
const float   f  = (float)i;
const double  d  = (double)f;
const int32_t i2 = (int32_t)3.99;   // = 3
const int8_t  b  = (int8_t)i;
```

**Rules**
- Conversion syntax `TargetType(value)` lowers to a C cast — no keyword.
- No implicit numeric coercion anywhere in Vertex.
- Float-to-integer truncates toward zero.
- Narrowing wraps on overflow (same behaviour as `&+`, `&-`, `&*`).

---

## 4. Arithmetic & Compound Assignment

**Vertex**
```vertex
a + b    a - b    a * b    a / b    a % b    -a
a += b   a -= b   a *= b   a /= b   a %= b
```

**C**
```c
a + b    a - b    a * b    a / b    a % b    -a
a += b   a -= b   a *= b   a /= b   a %= b
```

Direct one-to-one mapping; no ABI difference.

---

## 5. Bitwise Operators

**Vertex**
```vertex
~a    a & b    a | b    a ^ b    a << b    a >> b
```

**C**
```c
~a    a & b    a | b    a ^ b    a << b    a >> b
```

---

## 6. Overflow Operators

**Vertex**
```vertex
a &+ b
a &- b
a &* b
```

**C**
```c
uint32_t r = (uint32_t)a + (uint32_t)b;
uint32_t r = (uint32_t)a - (uint32_t)b;
uint32_t r = (uint32_t)a * (uint32_t)b;
```

Lowered by casting both operands to `uint32_t` before the operation.
C unsigned arithmetic wraps by definition.

---

## 7. Strings

**Vertex**
```vertex
let greeting = "hello"      // immutable
var name     = "hello"      // mutable
defer name.delete()
```

**C**
```c
// immutable — string lives in .rodata, no allocation
const char *greeting = "hello";

// mutable — heap copy managed by GLib
GString *name = g_string_new("hello");
g_string_free(name, TRUE);          // from defer
```

**Rules**
- `let` string → `const char *` pointing into read-only data.
- `var` string → `GString *` (heap); must be freed with `g_string_free`.
- `defer name.delete()` is hoisted to every return path as `g_string_free(name, TRUE)`.

---

## 8. Fixed Arrays

**Vertex**
```vertex
var buf  = [uint8](1024)                         // zero-filled
var mask = [uint8](repeating: 0xFF, count: 64)   // non-zero fill
let flags: [uint8] = [0xFF, 0x00, 0xAB]          // literal
var nums = [int32](5)

let first = nums[0]
nums[0] = 99
```

**C**
```c
uint8_t buf[1024];
memset(buf, 0, sizeof(buf));

uint8_t mask[64];
memset(mask, 0xFF, sizeof(mask));

const uint8_t flags[3] = { 0xFF, 0x00, 0xAB };

int32_t nums[5];
memset(nums, 0, sizeof(nums));

int32_t first = nums[0];
nums[0]       = 99;
```

**Rules**
- Fixed arrays are stack-allocated (`T name[N]`).
- `[T](n)` / `[T](repeating: 0, count: n)` → `T name[n]; memset(..., 0, ...)`.
- `[T](repeating: v, count: n)` with `v ≠ 0` → `memset(..., v, ...)`.
- Literals → C initializer list; `let` adds `const`.
- Size must be a compile-time integer literal.
- No `.delete()` needed — stack frame is freed automatically on scope exit.

---

## 9. Growable Arrays

### 9.1 Construction

**Vertex**
```vertex
var items = [int32]()              // empty
var items = [int32](capacity: 64)  // pre-allocated
defer items.delete()
```

**C**
```c
GArray *items = g_array_new(FALSE, FALSE, sizeof(int32_t));
GArray *items = g_array_sized_new(FALSE, FALSE, sizeof(int32_t), 64);
g_array_free(items, TRUE);         // from defer
```

### 9.2 Add / Remove

**Vertex**
```vertex
items.push(42)
items.unshift(0)

let last  = items.pop()    // int32?
let first = items.shift()  // int32?
```

**C**
```c
int32_t _push_val = 42;
g_array_append_val(items, _push_val);

int32_t _unshift_val = 0;
g_array_prepend_val(items, _unshift_val);

// pop — returns T?
int32_t *last = NULL, _last_tmp;
if (items->len > 0) {
    _last_tmp = g_array_index(items, int32_t, items->len - 1);
    last      = &_last_tmp;
    g_array_remove_index(items, items->len - 1);
}

// shift — returns T?
int32_t *first = NULL, _first_tmp;
if (items->len > 0) {
    _first_tmp = g_array_index(items, int32_t, 0);
    first      = &_first_tmp;
    g_array_remove_index(items, 0);
}
```

### 9.3 Access

**Vertex**
```vertex
let n    = items.length
let x    = items[0]
items[0] = 99
```

**C**
```c
uint32_t n = items->len;
int32_t  x = g_array_index(items, int32_t, 0);
g_array_index(items, int32_t, 0) = 99;
```

### 9.4 Search

**Vertex**
```vertex
let idx = items.indexOf(42)   // int32  (-1 if absent)
let has = items.includes(42)  // bool

let val = items.find(func(x: int32) -> bool { return x > 10 })

let i = items.findIndex(func(x: int32) -> bool { return x > 10 })
```

**C**
```c
int32_t idx = -1;
for (uint32_t _i = 0; _i < items->len; _i++) {
    if (g_array_index(items, int32_t, _i) == 42) { idx = (int32_t)_i; break; }
}

bool has = false;
for (uint32_t _i = 0; _i < items->len; _i++) {
    if (g_array_index(items, int32_t, _i) == 42) { has = true; break; }
}

int32_t *found = NULL;
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t *_p = &g_array_index(items, int32_t, _i);
    if (*_p > 10) { found = _p; break; }
}

int32_t find_idx = -1;
for (uint32_t _i = 0; _i < items->len; _i++) {
    if (g_array_index(items, int32_t, _i) > 10) { find_idx = (int32_t)_i; break; }
}
```

### 9.5 In-Place Mutation (no allocation)

**Vertex**
```vertex
items.sort(func(a: int32, b: int32) -> int32 { return a - b })
items.reverse()
items.fill(0)
items.fill(0, from: 1, to: 3)
```

**C**
```c
gint _cmp_int32(gconstpointer a, gconstpointer b) {
    return *(const int32_t *)a - *(const int32_t *)b;
}
g_array_sort(items, _cmp_int32);

for (uint32_t _lo = 0, _hi = items->len - 1; _lo < _hi; _lo++, _hi--) {
    int32_t _t = g_array_index(items, int32_t, _lo);
    g_array_index(items, int32_t, _lo) = g_array_index(items, int32_t, _hi);
    g_array_index(items, int32_t, _hi) = _t;
}

memset(items->data, 0, items->len * sizeof(int32_t));

// fill(0, from: 1, to: 3)
memset((int32_t *)items->data + 1, 0, (3 - 1) * sizeof(int32_t));
```

### 9.6 Allocating Methods (caller must `.delete()`)

**Vertex**
```vertex
var doubled = items.map(func(x: int32) -> int32 { return x * 2 })
defer doubled.delete()

var evens = items.filter(func(x: int32) -> bool { return x % 2 == 0 })
defer evens.delete()

var sub = items.slice(1, 3)
defer sub.delete()

var all = a.concat(b)
defer all.delete()
```

**C**
```c
GArray *doubled = g_array_sized_new(FALSE, FALSE, sizeof(int32_t), items->len);
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t _x = g_array_index(items, int32_t, _i), _out = _x * 2;
    g_array_append_val(doubled, _out);
}
g_array_free(doubled, TRUE);   // from defer

GArray *evens = g_array_new(FALSE, FALSE, sizeof(int32_t));
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t _x = g_array_index(items, int32_t, _i);
    if (_x % 2 == 0) g_array_append_val(evens, _x);
}
g_array_free(evens, TRUE);     // from defer

GArray *sub = g_array_new(FALSE, FALSE, sizeof(int32_t));
for (uint32_t _i = 1; _i < 3 && _i < items->len; _i++) {
    int32_t _x = g_array_index(items, int32_t, _i);
    g_array_append_val(sub, _x);
}
g_array_free(sub, TRUE);       // from defer

GArray *all = g_array_sized_new(FALSE, FALSE, sizeof(int32_t), a->len + b->len);
g_array_append_vals(all, a->data, a->len);
g_array_append_vals(all, b->data, b->len);
g_array_free(all, TRUE);       // from defer
```

### 9.7 Iteration

**Vertex**
```vertex
items.forEach(func(x: int32) { })
```

**C**
```c
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t x = g_array_index(items, int32_t, _i);
    (void)x;
}
```

### 9.8 Memory Rules

| Vertex method                              | Allocates | Required action         |
|--------------------------------------------|-----------|-------------------------|
| `push` `unshift` `fill` `sort` `reverse`   | no        | nothing                 |
| `pop` `shift`                              | no        | nothing                 |
| `map` `filter` `slice` `concat`            | yes       | `defer result.delete()` |
| `[T]()` `[T](capacity:)`                   | yes       | `defer items.delete()`  |

---

## 10. Struct Arrays

**Vertex**
```vertex
struct Vec2   { x: float32; y: float32 }
struct Player { id: int32; position: Vec2; health: int32 }

var players = [Player]()
defer players.delete()

players.push(Player{ id: 1, position: Vec2{x: 0.0, y: 0.0}, health: 100 })

players[0].health = 50

let found = players.find(func(p: Player) -> bool { return p.health < 100 })

let idx = players.findIndex(func(p: Player) -> bool { return p.id == 2 })

players.sort(func(a: Player, b: Player) -> int32 { return a.health - b.health })

var alive = players.filter(func(p: Player) -> bool { return p.health > 0 })
defer alive.delete()

var ids = players.map(func(p: Player) -> int32 { return p.id })
defer ids.delete()

players.forEach(func(p: Player) { })
```

**C**
```c
typedef struct { float x; float y; }                          Vec2;
typedef struct { int32_t id; Vec2 position; int32_t health; } Player;

GArray *players = g_array_new(FALSE, FALSE, sizeof(Player));
g_array_free(players, TRUE);   // from defer

Player _p1 = { .id = 1, .position = { .x = 0.0f, .y = 0.0f }, .health = 100 };
g_array_append_val(players, _p1);   // copied by value

g_array_index(players, Player, 0).health = 50;

Player *found = NULL;
for (uint32_t _i = 0; _i < players->len; _i++) {
    Player *_p = &g_array_index(players, Player, _i);
    if (_p->health < 100) { found = _p; break; }
}

int32_t idx = -1;
for (uint32_t _i = 0; _i < players->len; _i++) {
    if (g_array_index(players, Player, _i).id == 2) { idx = (int32_t)_i; break; }
}

gint _cmp_player_health(gconstpointer a, gconstpointer b) {
    return ((const Player *)a)->health - ((const Player *)b)->health;
}
g_array_sort(players, _cmp_player_health);

GArray *alive = g_array_new(FALSE, FALSE, sizeof(Player));
for (uint32_t _i = 0; _i < players->len; _i++) {
    Player _p = g_array_index(players, Player, _i);
    if (_p.health > 0) g_array_append_val(alive, _p);
}
g_array_free(alive, TRUE);     // from defer

GArray *ids = g_array_sized_new(FALSE, FALSE, sizeof(int32_t), players->len);
for (uint32_t _i = 0; _i < players->len; _i++) {
    int32_t _id = g_array_index(players, Player, _i).id;
    g_array_append_val(ids, _id);
}
g_array_free(ids, TRUE);       // from defer

for (uint32_t _i = 0; _i < players->len; _i++) {
    Player p = g_array_index(players, Player, _i);
    (void)p;
}
```

Structs are copied by value into `GArray` on every `push` and out again on iteration.

---

## 11. Dictionaries

**Vertex**
```vertex
var config = {"debug": 0}
config["verbose"] = 1

let val = config["debug"]      // int?
config["debug"] = nil           // removes key

defer config.delete()
```

**C**
```c
GHashTable *config = g_hash_table_new(g_str_hash, g_str_equal);
g_hash_table_insert(config, "debug",   GINT_TO_POINTER(0));
g_hash_table_insert(config, "verbose", GINT_TO_POINTER(1));

gpointer _val_raw = g_hash_table_lookup(config, "debug");
bool     _val_has = (_val_raw != NULL);
int32_t  _val     = GPOINTER_TO_INT(_val_raw);

g_hash_table_remove(config, "debug");

g_hash_table_destroy(config);   // from defer
```

**Iteration (internal, used by Lowerer):**

```c
GHashTableIter _iter;
gpointer       _k, _v;
g_hash_table_iter_init(&_iter, config);
while (g_hash_table_iter_next(&_iter, &_k, &_v)) {
    const char *key = (const char *)_k;
    int32_t     val = GPOINTER_TO_INT(_v);
}
```

---

## 12. Structs

**Vertex**
```vertex
struct Point { x: int32; y: int32 }

let p  = Point{x: 3, y: 4}
var q  = Point{x: 3, y: 4}
q.y    = 10
let p2 = p                         // full value copy

struct Line { start: Point; end: Point }

let l = Line{
    start: Point{x: 0,  y: 0},
    end:   Point{x: 10, y: 10},
}
```

**C**
```c
typedef struct { int32_t x; int32_t y; } Point;

const Point p = { .x = 3, .y = 4 };
Point       q = { .x = 3, .y = 4 };
q.y           = 10;
Point p2      = p;                   // copied by value

typedef struct { Point start; Point end; } Line;

const Line l = {
    .start = { .x = 0,  .y = 0  },
    .end   = { .x = 10, .y = 10 },
};
```

**Rules**
- Structs are pure data — no vtable, no heap allocation.
- `let` → `const` struct; all fields frozen.
- `var` → non-const; fields are assignable.
- Assignment always copies the full value.

---

## 13. Classes

**Vertex**
```vertex
class Animal {
    name: string
}

func (a: *Animal) init(name: string) {
    a.name = name
}

func (a: *Animal) deinit() {
    // cleanup
}

let a = Animal(name: "Rex")
a.delete()
```

**C**
```c
typedef struct {
    const char *name;
} Animal;

void Animal__init(Animal *a, const char *name) {
    a->name = name;
}

void Animal__deinit(Animal *a) {
    // user cleanup
}

Animal *a = malloc(sizeof(Animal));
Animal__init(a, "Rex");

// a.delete()
Animal__deinit(a);
free(a);
```

**Rules**
- Classes are heap-allocated (`malloc` / `free`).
- `init` and `deinit` take a `*ClassName` receiver and lower to free functions (`Animal__init`, `Animal__deinit`).
- The compiler calls `init` immediately after `malloc`, and `deinit` before `free`.
- `.delete()` and `.new()` are mutually exclusive.

---

## 14. Reference Counting — `.new()`

**Vertex**
```vertex
let a = Animal(name: "Rex").new()
let b = a                    // retain — count = 2
// b scope ends → count = 1
// a scope ends → count = 0 → deinit + free

weak let w = a               // non-owning, count stays 1
if let animal = w { }
```

**C**
```c
typedef struct {
    int32_t     ref_count;
    const char *name;
} Animal;

Animal *Animal__retain(Animal *a)  { a->ref_count++; return a; }
void    Animal__release(Animal *a) {
    if (--a->ref_count == 0) { Animal__deinit(a); free(a); }
}

Animal *a = malloc(sizeof(Animal));
a->ref_count = 1;
Animal__init(a, "Rex");

Animal *b = Animal__retain(a);  // count = 2

Animal__release(b);             // count = 1
Animal__release(a);             // count = 0 → deinit + free

// weak — no retain
Animal *w = a;
// compiler injects: w = NULL; when owning count hits 0
```

The `ref_count` field is injected into the struct layout by the Lowerer.

---

## 15. Associated Functions (Receiver Syntax)

**Vertex**
```vertex
func (p: Point) describe() {
    let n = p.x
}

func (p: *Point) reset() {
    p.x = 0
    p.y = 0
}

p.describe()
q.reset()
```

**C**
```c
void Point__describe(Point p) {      // value receiver — copy
    int32_t n = p.x;
    (void)n;
}

void Point__reset(Point *p) {        // pointer receiver
    p->x = 0;
    p->y = 0;
}

Point__describe(p);                  // compiler dispatches
Point__reset(&q);                    // compiler inserts &
```

**Rules**
- Receiver name + type → `TypeName__functionName` in C.
- Value receiver `T` → passed by value.
- Pointer receiver `*T` → passed as pointer; compiler inserts `&` at call sites.
- Reads and writes through a pointer receiver are auto-dereferenced; `.` in Vertex lowers to `->` in C.
- `self` / `this` do not exist; the receiver is named explicitly.

---

## 16. Pointer Parameters

**Vertex**
```vertex
func increment(n: *int32) {
    n += 1
}

var count = 0
increment(n: &count)
```

**C**
```c
void increment(int32_t *n) {
    *n += 1;
}

int32_t count = 0;
increment(&count);
```

**Rules**
- `*T` parameters lower to C pointer parameters.
- Caller passes the address with `&`.
- Reads and writes to the parameter are auto-dereferenced by the compiler; `n += 1` in Vertex lowers to `*n += 1` in C.

---

## 17. Enums

**Vertex**
```vertex
enum Direction { case north, south, east, west }

enum Status: int {
    case inactive = 0
    case active   = 1
    case pending  = 2
}

let s   = Status.active
let raw = Status.active.rawValue    // 1

let fromRaw: Status? = Status(rawValue: 1)

switch dir {
case .north: …
case .south: …
case .east:  …
case .west:  …
}
```

**C**
```c
typedef enum {
    Direction_north, Direction_south, Direction_east, Direction_west,
} Direction;

typedef enum {
    Status_inactive = 0,
    Status_active   = 1,
    Status_pending  = 2,
} Status;

Status  s   = Status_active;
int32_t raw = (int32_t)Status_active;

// Status(rawValue: 1) → optional, bounds-checked
Status  _s_tmp;
Status *fromRaw = NULL;
if (1 >= Status_inactive && 1 <= Status_pending) {
    _s_tmp  = (Status)1;
    fromRaw = &_s_tmp;
}

switch (dir) {
    case Direction_north: /* ... */ break;
    case Direction_south: /* ... */ break;
    case Direction_east:  /* ... */ break;
    case Direction_west:  /* ... */ break;
}
```

---

## 18. Optionals

**Vertex**
```vertex
// class / pointer type
var maybe: Animal? = nil
if let val = maybe { }
let r = maybe ?? defaultAnimal

// scalar type
var maybe: int32? = nil
maybe = 5
if let val = maybe { }
```

**C**
```c
// class path — nullable pointer
Animal *maybe = NULL;
if (maybe != NULL) { Animal *val = maybe; (void)val; }
Animal *r = (maybe != NULL) ? maybe : defaultAnimal;

// scalar path — tagged struct
typedef struct { int32_t value; bool has_value; } opt_int32;
opt_int32 maybe = { .has_value = false };
maybe.value = 5; maybe.has_value = true;
if (maybe.has_value) { int32_t val = maybe.value; (void)val; }
```

- Pointer/class optionals → nullable pointer (`NULL` is nil).
- Scalar optionals → `{ T value; bool has_value; }` tagged struct.

---

## 19. Result

**Vertex**
```vertex
func parseInt(s: string) -> Result(int32, string) {
    if s == "" { return Result(Err, "empty string") }
    return Result(Ok, 42)
}

// propagate
let n = parseInt(s).try()

// switch
switch parseInt(s) {
case Ok(let value): …
case Err(let err):  …
}
```

**C**
```c
typedef enum  { RESULT_OK, RESULT_ERR } _ResultTag;
typedef struct {
    _ResultTag tag;
    union { int32_t ok; const char *err; };
} Result_int32_string;

Result_int32_string parseInt(const char *s) {
    if (strcmp(s, "") == 0)
        return (Result_int32_string){ .tag = RESULT_ERR, .err = "empty string" };
    return (Result_int32_string){ .tag = RESULT_OK, .ok = 42 };
}

// .try() — early return on Err, unwrap on Ok
Result_int32_string _r0 = parseInt(s);
if (_r0.tag == RESULT_ERR)
    return (Result_int32_string){ .tag = RESULT_ERR, .err = _r0.err };
int32_t n = _r0.ok;

// switch
Result_int32_string _res = parseInt(s);
if (_res.tag == RESULT_OK) {
    int32_t     value = _res.ok;  (void)value;
} else {
    const char *err   = _res.err; (void)err;
}
```

`Result(T, E)` lowers to a tagged union: a `_ResultTag` enum plus a `union` of the two payload types.

---

## 20. Tuples

**Vertex**
```vertex
let pair  = (1, true)
let point = (x: 10, y: 20)

let (a, b) = pair

func minMax(values: [int32]) -> (min: int32, max: int32) {
    return (0, 100)
}
let (lo, hi) = minMax(values: nums)
```

**C**
```c
typedef struct { int32_t _0; bool _1; }    _tuple_int32_bool;
typedef struct { int32_t x;  int32_t y; }  _tuple_x_y;

const _tuple_int32_bool pair  = { ._0 = 1,  ._1 = true };
const _tuple_x_y        point = { .x  = 10, .y  = 20   };

int32_t a = pair._0;
bool    b = pair._1;

typedef struct { int32_t min; int32_t max; } _ret_minMax;
_ret_minMax minMax(GArray *values) {
    return (_ret_minMax){ .min = 0, .max = 100 };
}
_ret_minMax _mm = minMax(nums);
int32_t lo = _mm.min;
int32_t hi = _mm.max;
```

Tuples lower to anonymous `typedef struct` types. Unlabelled elements become `_0`, `_1`, …; labelled elements use their label as the field name.

---

## 21. Functions

**Vertex**
```vertex
func add(a: int32, b: int32) -> int32 {
    return a + b
}

add(1, 2)           // positional
add(a: 1, b: 2)    // labelled (equivalent)
```

**C**
```c
int32_t add(int32_t a, int32_t b) {
    return a + b;
}

add(1, 2);
```

Labels are erased at the call site; the lowered C call is always positional.

---

## 22. Anonymous Functions

### 22.1 No captures — plain function pointer

**Vertex**
```vertex
let double_fn = func(n: int32) -> int32 { return n * 2 }
let r = double_fn(21)
```

**C**
```c
int32_t _anon_0(int32_t n) { return n * 2; }
int32_t (*double_fn)(int32_t) = _anon_0;
int32_t r = double_fn(21);
```

### 22.2 Captured value — closure struct + trampoline

**Vertex**
```vertex
let factor   = 3
let multiply = func(n: int32) -> int32 { return n * factor }
// call: multiply(5) → 15
```

**C**
```c
typedef struct { int32_t factor; } _env_multiply;

int32_t _multiply_call(void *env, int32_t n) {
    return ((_env_multiply *)env)->factor * n;
}

_env_multiply _multiply_env = { .factor = 3 };
// call: _multiply_call(&_multiply_env, 5)
```

Captured values are copied into a heap or stack environment struct at creation.
Mutations inside the anonymous function do not affect the original binding.

### 22.3 Inline higher-order patterns

**Vertex**
```vertex
items.map(func(x: int32) -> int32    { return x * 2      })
items.filter(func(x: int32) -> bool  { return x % 2 == 0 })
items.sort(func(a: int32, b: int32) -> int32 { return a - b })
```

**C**
```c
// map
GArray *doubled = g_array_sized_new(FALSE, FALSE, sizeof(int32_t), items->len);
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t _x = g_array_index(items, int32_t, _i), _out = _x * 2;
    g_array_append_val(doubled, _out);
}

// filter
GArray *evens = g_array_new(FALSE, FALSE, sizeof(int32_t));
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t _x = g_array_index(items, int32_t, _i);
    if (_x % 2 == 0) g_array_append_val(evens, _x);
}

// sort
gint _cmp_int32(gconstpointer a, gconstpointer b) {
    return *(const int32_t *)a - *(const int32_t *)b;
}
g_array_sort(items, _cmp_int32);
```

---

## 23. Generics

**Vertex**
```vertex
func identity<T>(value: T) -> T { return value }
let r = identity(value: 42)

struct Box<T> { value: T }
let b = Box{value: 42}
```

**C**
```c
// Monomorphised — one copy per concrete type, no runtime polymorphism
int32_t identity_int32(int32_t value) { return value; }
int32_t r = identity_int32(42);

typedef struct { int32_t value; } Box_int32;
const Box_int32 b = { .value = 42 };
```

The type parameter is erased; the Lowerer emits one concrete C function / struct per instantiation.

---

## 24. Defer

**Vertex**
```vertex
func main() -> int32 {
    defer config.delete()   // declared first
    defer items.delete()    // declared second
    return 0
}
```

**C — LIFO, hoisted before every return path**
```c
int32_t main(void) {
    // … body …
    g_array_free(items, TRUE);       // runs first  (declared second)
    g_hash_table_destroy(config);    // runs second (declared first)
    return 0;
}
```

`defer` is not a runtime mechanism — the Lowerer inserts the calls statically before each `return` in reverse declaration order.

---

## 25. If / Else

**Vertex**
```vertex
if x > 0 {
    // positive
} else if x < 0 {
    // negative
} else {
    // zero
}
```

**C**
```c
if (x > 0) {
    /* positive */
} else if (x < 0) {
    /* negative */
} else {
    /* zero */
}
```

---

## 26. Switch

### 26.1 Integer

**Vertex**
```vertex
switch x {
case 0:    …
case 1, 2: …
default:   …
}
```

**C**
```c
switch (x) {
    case 0:         /* … */ break;
    case 1: case 2: /* … */ break;
    default:        /* … */ break;
}
```

### 26.2 String (no C `switch`)

**Vertex**
```vertex
switch s {
case "hello": …
case "world": …
default:      …
}
```

**C**
```c
if      (strcmp(s, "hello") == 0) { /* hello */ }
else if (strcmp(s, "world") == 0) { /* world */ }
else                               { /* default */ }
```

### 26.3 Enum

**Vertex**
```vertex
switch dir {
case .north: …
case .south: …
case .east:  …
case .west:  …
}
```

**C**
```c
switch (dir) {
    case Direction_north: /* … */ break;
    case Direction_south: /* … */ break;
    case Direction_east:  /* … */ break;
    case Direction_west:  /* … */ break;
}
```

### 26.4 Explicit Fallthrough

**Vertex**
```vertex
switch x {
case 0:
    fallthrough
case 1:
    // zero or one
default: …
}
```

**C**
```c
switch (x) {
    case 0:  goto _label_case1;
    case 1: _label_case1:
             /* zero or one */
             break;
    default: break;
}
```

Vertex has no implicit fallthrough; `fallthrough` lowers to a `goto` targeting the next case label.

---

## 27. Loops

### 27.1 For-In (range)

**Vertex**
```vertex
for i in 0..<5 { }
for i in 0...5 { }
```

**C**
```c
for (int32_t i = 0; i < 5;  i++) { }
for (int32_t i = 0; i <= 5; i++) { }
```

### 27.2 For-In (array)

The lowering depends on whether the array is fixed or growable.

**Fixed array**

**Vertex**
```vertex
let nums = [1, 2, 3]
for n in nums { }
```

**C**
```c
const int32_t nums[3] = { 1, 2, 3 };
for (uint32_t _i = 0; _i < 3; _i++) {
    int32_t n = nums[_i];
    (void)n;
}
```

The length is emitted as a compile-time literal — the compiler knows the count from the type.

**Growable array**

**Vertex**
```vertex
var items = [int32]()
for n in items { }
```

**C**
```c
for (uint32_t _i = 0; _i < items->len; _i++) {
    int32_t n = g_array_index(items, int32_t, _i);
    (void)n;
}
```

### 27.3 While

**Vertex**
```vertex
var i = 0
while i < 5 { i += 1 }
```

**C**
```c
int32_t i = 0;
while (i < 5) { i += 1; }
```

### 27.4 Break / Continue

**Vertex**
```vertex
for i in 0..<10 {
    if i % 2 == 0 { continue }
    if i == 7     { break }
}
```

**C**
```c
for (int32_t i = 0; i < 10; i++) {
    if (i % 2 == 0) continue;
    if (i == 7)     break;
}
```

---

## 28. Ternary and Nil-Coalescing

**Vertex**
```vertex
let r    = x > 0 ? a : b
let name = maybe ?? defaultAnimal           // class type
let n    = maybe ?? 0                       // scalar optional
```

**C**
```c
int32_t  r    = (x > 0)           ? a            : b;
Animal  *name = (maybe != NULL)   ? maybe         : defaultAnimal;
int32_t  n    = (maybe.has_value) ? maybe.value   : 0;
```

---

## 29. Channels

**Vertex**
```vertex
let ch = string.channel(size: 32)

ch.send("hello")
let val = ch.receive()

let ok   = ch.trySend("hello")   // bool
let val2 = ch.tryReceive()       // string?

ch.close()
```

**C — GAsyncQueue + semaphore tokens for bounded buffer**
```c
GAsyncQueue *ch    = g_async_queue_new();
GAsyncQueue *ch_wr = g_async_queue_new();         // write-permit semaphore
for (int _i = 0; _i < 32; _i++)
    g_async_queue_push(ch_wr, GINT_TO_POINTER(1));

// send — blocks until permit available
g_async_queue_pop(ch_wr);
g_async_queue_push(ch, "hello");

// receive — blocks until value available, returns permit
const char *val = (const char *)g_async_queue_pop(ch);
g_async_queue_push(ch_wr, GINT_TO_POINTER(1));

// trySend
bool _ok = (g_async_queue_try_pop(ch_wr) != NULL);
if (_ok) g_async_queue_push(ch, "hello");

// tryReceive
const char *val2 = (const char *)g_async_queue_try_pop(ch);

// close — NULL sentinel
g_async_queue_push(ch, NULL);
```

| Vertex operation | Blocks | C mechanism                                 |
|------------------|--------|---------------------------------------------|
| `.send(v)`       | yes    | `g_async_queue_pop(ch_wr)` + `push(ch, v)`  |
| `.receive()`     | yes    | `g_async_queue_pop(ch)`                     |
| `.trySend(v)`    | no     | `try_pop(ch_wr)` — returns `false` if full  |
| `.tryReceive()`  | no     | `g_async_queue_try_pop(ch)` — NULL if empty |
| `.close()`       | no     | `push(ch, NULL)` sentinel                   |

---

## 30. Threads

**Vertex**
```vertex
func crunchData(data: [float32]) thread -> [float32] { … }
let result = crunchData(data: x).spawn()
```

**C**
```c
typedef struct { GArray *data; GArray *result; } _args_crunchData;

gpointer _thread_crunchData(gpointer arg) {
    _args_crunchData *a = (_args_crunchData *)arg;
    a->result = crunchData_body(a->data);
    return NULL;
}

_args_crunchData _targs = { .data = x };
GThread *_th = g_thread_new("crunchData", _thread_crunchData, &_targs);
g_thread_join(_th);
GArray *result = _targs.result;
```

Arguments and return value are packed into a shared struct; the thread writes its result back before returning.

---

## 31. Async / Await

**Vertex**
```vertex
func fetchUser(id: int32) async -> User { … }
let user = fetchUser(id: 1).await()
```

**C**
```c
void _gtask_fetchUser(GTask *task, gpointer src,
                      gpointer task_data, GCancellable *cancel) {
    int32_t id     = GPOINTER_TO_INT(task_data);
    User   *result = fetchUser_body(id);
    g_task_return_pointer(task, result, NULL);
}

GTask *_t = g_task_new(NULL, NULL, NULL, NULL);
g_task_set_task_data(_t, GINT_TO_POINTER(1), NULL);
g_task_run_in_thread_sync(_t, _gtask_fetchUser);
User *user = (User *)g_task_propagate_pointer(_t, NULL);
g_object_unref(_t);
```

---

## 32. Processes

**Vertex**
```vertex
func isolatedWork(data: [float32]) process -> [float32] { … }
let result = isolatedWork(data: x).fork()
```

**C**
```c
int _pipe_fds[2];
pipe(_pipe_fds);

pid_t _pid = fork();
if (_pid == 0) {
    // child — isolated memory
    close(_pipe_fds[0]);
    GArray *_out = isolatedWork_body(x);
    write(_pipe_fds[1], _out->data, _out->len * sizeof(float));
    _exit(0);
} else {
    // parent — read result back
    close(_pipe_fds[1]);
    GArray *result = g_array_new(FALSE, FALSE, sizeof(float));
    float   _fbuf;
    while (read(_pipe_fds[0], &_fbuf, sizeof(float)) == sizeof(float))
        g_array_append_val(result, _fbuf);
    close(_pipe_fds[0]);
    waitpid(_pid, NULL, 0);
}
```

Processes use POSIX `fork` + a pipe for data transfer — GLib has no equivalent primitive.

---

## 33. Complete End-to-End Example

**Vertex**
```vertex
func main() -> int32 {
    var config = ["debug": 0]
    config["verbose"] = 1
    defer config.delete()
    return 0
}
```

**C**
```c
int32_t main(void) {
    GHashTable *config = g_hash_table_new(g_str_hash, g_str_equal);
    g_hash_table_insert(config, "debug",   GINT_TO_POINTER(0));
    g_hash_table_insert(config, "verbose", GINT_TO_POINTER(1));
    g_hash_table_destroy(config);   // defer hoisted before return
    return 0;
}
```

---

## Appendix — Postfix Intrinsic Summary

| Vertex postfix           | C / GLib mechanism                         |
|--------------------------|--------------------------------------------|
| `.new()`                 | `malloc` + `ref_count = 1`                 |
| `.delete()`              | `deinit` call + `free`                     |
| `.try()`                 | early `return` on `RESULT_ERR`             |
| `.await()`               | `GTask` + `g_task_run_in_thread_sync`      |
| `.spawn()`               | `g_thread_new` + `g_thread_join`           |
| `.fork()`                | `fork()` + POSIX pipe                      |
| `.dispatch()`            | GPU kernel launch (platform ABI)           |
| `T.channel(size: n)`     | `GAsyncQueue` pair (data + permit queue)   |
| `defer f()`              | static insertion before every `return`     |