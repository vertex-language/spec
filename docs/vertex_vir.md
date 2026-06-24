# vertex_vir.md

# Vertex → Virtual IR Lowering Map

Maps Vertex 2.2 (high-level) constructs to Virtual IR 1.3 (VIR). VIR derives its
type/instruction model from Wasm 3.0, so "Wasm core" means the inherited Core
instruction set. This revision assumes the additions in `proposed.md` are
adopted; lowerings that depend on them are tagged **(proposed §X)**.

Legend:
- **VIR** — a native Virtual IR extension instruction/type (Part I).
- **Wasm core** — inherited Wasm 3.0 instruction (Part II).
- **(proposed §X)** — relies on an addition from `proposed.md`.
- **frontend** — lowered by the Vertex compiler before VIR; no VIR primitive.
- **runtime** — provided by the Vertex runtime library over VIR primitives; needs a runtime-ABI doc.
- **TODO** — a plausible lowering exists but is not yet pinned down.
- **UNIMPLEMENTED** — no VIR construct covers this; needs a design decision.

Native lowerings assume a `target` declaration. Storage classes, `ptr.*`,
overflow-checked arithmetic, `cleanup.region`, addressable locals, `rc.*`, etc.
are native-backend only and invalid inside a device function (§D).

---

## §1 Literals

| Vertex | VIR | Notes |
|---|---|---|
| `42`, `0xFF`, `0b1010`, `0o52` | `i32.const` / `i64.const` (Wasm core) | base/underscores lexical only |
| `3.14`, `1.25e2`, `0xFp2` | `f32.const` / `f64.const` (Wasm core) | hex-float resolved at parse time |
| `true` / `false` | `i32.const 1` / `0` | i32 doubles as boolean |
| `nil` (pointer/class) | `ref.null` (Wasm core) / `ptr.null` (§8.4) | depends on target type |
| `nil` (scalar optional) | `has_value = 0` in the optional struct (§27) | |
| `"hello"`, backtick string (`let`) | `(data …)` segment + `data.addr` (§8.7) → rodata | |
| `"hello"` (`var`) | heap `[uint8]` copy — **runtime** (string ABI) | |
| `'A'` (char) | `i32.const`; packs to `i8` only in aggregates | |

---

## §2 Variable Declarations

| Vertex | VIR |
|---|---|
| `let`/`var` in a function | `(local …)` (Wasm core); `let` immutability is **frontend**-enforced |
| `let`/`var` at package level | `(global … imm/mut …)` |

---

## §3 Type Annotations (scalars)

| Vertex | VIR value type |
|---|---|
| `int`/`int32`, `uint`/`uint32` | `i32` |
| `int8/16`, `uint8/16` | `i32` (value form); packed `i8`/`i16` only inside aggregates |
| `int64`, `uint64` | `i64` |
| `float32` / `float64` | `f32` / `f64` |
| `bool`, `char` | `i32` (`char`→`i8` packed in aggregates) |
| `string` | `data.addr` (`let`) / heap `[uint8]` (`var`, **runtime**) |
| `void` / `()` | empty result type `[]` |

Signedness is per-instruction (`div_s` vs `div_u`, etc.), not a type; the
frontend picks the variant for the Vertex type.

---

## §4 Pointer Types

| Vertex | VIR |
|---|---|
| `*T` | `(ptr $t)` / `(ptr numtype)` (§8.1) |
| `*const T` | same `(ptr …)` — `const` is compile-time only, **frontend**-enforced |
| `*T?` | `ptr` with `ptr.null` zero value (§8.4) |
| `**T` | `(ptr (ptr …))` |
| `&x` (scalar local) | `local.addr` on an `addressable` local/param (§8.5–8.6) |
| `&point.x` | `struct.addr` + `ptr.field` (§8.2, §8.4) |
| `&buf[0]` | `array.addr` + `ptr.elem` (§8.2, §8.4) |
| `*void` | untyped `(ptr)` |
| `*ClassName` | Vertex compile error — never lowered |

Auto-deref of pointer params/receivers lowers to explicit `*.load`/`*.store`.

---

## §5 Type Aliases

**frontend** — resolved at compile time, no VIR representation (§5).

---

## §6 / §48 Variadic & Native Interface

| Vertex | VIR |
|---|---|
| `func printf(fmt: ...*const char)` on `class : c` | `import … (func (cconv sysv64) variadic (param $fmt ptr) (result i32))` (§9.6) |
| `class C : c` / `class IUnknown : d3d11` methods | extern `import "<platform>:<lib>" "<name>" (func …)` (§14.1) |
| **Vertex-defined** variadic body (`func log(…, msg: ...string)`) | `va.start`/`va.arg`/`va.end` over a `valist`, with the §9.6 extern-only restriction lifted — **(proposed §C)** |

---

## §7 / §7.1 Numeric Conversion & `as`

| Vertex | VIR (Wasm core unless noted) |
|---|---|
| `int → float` | `convert_iNN_sx` |
| `float → int` (truncate) | `trunc_sat_fNN_sx` |
| widening `int32 → int64` | `extend_i32_s/_u` |
| narrowing (wrap) | `wrap_i64` / i32 mask |
| `ptr → ptr` (no-op) | identity retype |
| `ptr → int` / `int → ptr` | `ptr.to_i64` / `ptr.from_i64` (§8.4) |
| chained `as` | sequence, left-assoc |

`&+ &- &*` are plain wrapping `add/sub/mul` (silent wrap is the Wasm default);
overflow-**checked** arithmetic uses VIR `add_ovf_s/u` etc. (§11).

---

## §8–§13 Operators

| Vertex | VIR (Wasm core unless noted) |
|---|---|
| `+ - * / %` (int) | `add sub mul div_sx rem_sx` |
| `+ - * /` (float) | `f.add/sub/mul/div` |
| `-a` / `~a` | `sub 0 a` / `f.neg`; `xor a -1` |
| `& \| ^ << >>` | `and or xor shl shr_sx` |
| `&+ &- &*` | plain `add sub mul` |
| comparisons | `eq ne lt_sx gt_sx le_sx ge_sx` / float variants |
| `+=` etc. (§9) | `local.tee`/`local.get` + op + `local.set`, or load/op/store via pointer |
| `!a` | `i32.eqz` |
| `a && b`, `a \|\| b` | `if`/`else` (short-circuit) — not `select` |

---

## §14–§17 Range / Ternary / Nil-Coalescing / Identity

| Vertex | VIR |
|---|---|
| `0...5`, `0..<5` | **frontend** — loop bounds; no VIR range type |
| `cond ? a : b` | `select` (pure) / `if`/`else` (side effects) |
| `a ?? b` (ref) | `ref.is_null` + `select`/`if` |
| `a ?? b` (scalar opt) | test `has_value` + `select` (§27) |
| `a === b` / `a !== b` | `ref.eq` (Wasm core) |

---

## §19–§21 Control Flow

| Vertex | VIR |
|---|---|
| `if / else if / else` | `if`/`else`/`end` |
| `switch` (int/enum) | `br_table` / chained `if` |
| `switch` (string) | comparison chain (no VIR string switch) |
| `fallthrough` | fall into the next case's block |
| `break` / `continue` | `br` to the enclosing block / loop label |

Exhaustiveness and empty-case checks are **frontend**.

---

## §22 Functions

| Vertex | VIR |
|---|---|
| `func add(a,b) -> int32` | `(func (param …) (result …))` |
| labeled call | positional `call` — labels erased (frontend) |
| pointer param `n: *int32` | `(param $n addressable? (ptr i32))`; writes via `*.store` |
| execution sigils | spawn / launch at the call site (§39–§40) |

---

## §23–§24 Loops

| Vertex | VIR |
|---|---|
| `while c {}` | `block` + `loop` + `br_if` |
| `for i in 0..<n` | `loop` + `i32` counter + `br_if` |
| `for x in array` | `loop` with `array.get`/`array.len`, or `ptr.elem` walk |

Loop shape is **frontend**; backend yield checks at back-edges satisfy
virtual-thread scheduling (§16.3).

---

## §25 Arrays

### Fixed `[T; N]` (stack)
| Vertex | VIR |
|---|---|
| `var buf: [uint8; 1024]` | `stack` array via `array.new_fixed` (§4.3) |
| read/write | `array.get_sx` / `array.set` |
| `.fill(v)` / `.length` | `array.fill` / `array.len` |
| freed at scope exit | automatic (stack storage) |

### Dynamic `[T]` (heap)
| Vertex | VIR |
|---|---|
| `var x: [int32] = []` | `rc` struct `{ data:(ptr), len:i64, cap:i64 }` + `rc` backing buffer — layout is **runtime** (array ABI) |
| `.delete()` | `rc.release` on the array's rc allocation — **(proposed §A)** |
| `defer x.delete()` | `cleanup.region` handler calling `rc.release` (§18, proposed §A) |

### Methods
- `push pop shift unshift reserve` — **runtime** (growth policy over the array struct).
- `map filter slice concat` — **runtime** (allocate new array; result freed via `rc.release`).
- `sort reverse fill forEach indexOf includes find findIndex` — **runtime**; callbacks lower to `closure.new`/`closure.call` (§19).

---

## §26 Maps

`map[K]V`, literals, `["k"]`, `nil`-delete — **runtime** (hash-map library over
`rc` + `ptr.*`). `.delete()` → `rc.release` on the map's rc allocation
**(proposed §A)**. No VIR map primitive.

---

## §27 Optionals

| Vertex | VIR |
|---|---|
| scalar `T?` | `stack`/`rc` struct `{ value:T, has_value:i32 }` |
| pointer/class `T?` | `(ref null $t)` / `ptr` with `ptr.null` |
| `if let v = opt` | `ref.is_null`/`br_on_null` (refs) or `has_value` test (scalar) |
| `opt ?? default` | see §16 |

---

## §28 Structs

| Vertex | VIR |
|---|---|
| `struct Point {x,y}` | `(type $Point (stack (struct (field $x i32) (field $y i32))))` |
| `Point{…}` | `struct.new $Point` |
| read `p.x` / write `q.y=…` | `struct.get` / `struct.set` |
| `let p2 = p` (value copy) | `struct.clone $Point` (§17) |
| copy into existing dest | `struct.copy $Point` (§17) |

`let`/`var` field freezing is **frontend**-enforced.

---

## §29 Associated Functions (receivers)

| Vertex receiver | VIR |
|---|---|
| value `(p: T)` | first `param` by value; mutations on a `struct.clone` copy (or `byval`, §9.7) |
| pointer `(p: *T)` | first `param` `(ptr $T)` (often `addressable`); `.x` → `ptr.field` + load/store |
| class `(a: Animal)` | first `param` `(ref $Animal)`; `.name` → `struct.get`/`struct.set` |
| auto-`&` at call | `struct.addr`/`local.addr` inserted by frontend |

---

## §30 Enums

**frontend.** int enums → `i32.const`; string enums → `data.addr` constants;
`rawValue` → the constant; `EnumType(rawValue:)` → frontend table → `T?`;
comparisons → `i32` ops. No VIR enum type. Associated values **UNIMPLEMENTED**.

---

## §31 / §31.1 Classes & Reference Counting

| Vertex | VIR |
|---|---|
| `class Animal { name }` | `(type $Animal (rc (struct (field $name …)) (deinit $Animal_deinit)?))` — **(proposed §A)** for the optional `deinit` clause |
| instance | `(ref $Animal)` / `(ref null $Animal)` |
| `Animal(name:)` | `struct.new $Animal` under `rc` |
| `init` | constructor run after allocation (frontend wires the call) |
| `deinit` | declared via the rc `deinit` clause; run by `rc.release` at strong-count zero — **(proposed §A)** |
| **manual class** `Animal(...)` + `.delete()` | `rc` with copies **uncounted** (frontend emits no `rc.retain`); `.delete()` → a single `rc.release` (1 → 0 → deinit + free). The release **consumes** the binding (frontend move-tracking) so the scope-exit auto-release does not double-free — **(proposed §A)** |
| **counted class** `.new()` | `rc` with `rc.retain` on each copy; scope exits auto-release; `deinit` at the dynamic zero — **(proposed §A)** |
| `weak Foo?` / `weak let b = a` | `(ref weak $t)` (§6); `ref.weaken` / `ref.upgrade`; weak refs become `nil` after strong-zero |
| `===` / `!==` | `ref.eq` |
| `shared` counting | `shared rc` (§7); `rc.retain`/`rc.release` use the atomic form |

Note: at strong-zero `rc.release` runs `deinit` and drops the value; the
allocation header survives until weak-count zero (Rust `Rc`/`Weak`, §6.4) so
outstanding `weak` refs and `ref.upgrade` stay sound.

---

## §32 Defer

| Vertex | VIR |
|---|---|
| `defer a.delete()` | `cleanup.region` handler calling `rc.release` (§18, proposed §A) |
| multiple `defer` (LIFO) | multiple `cleanup` handlers (LIFO) |
| `defer func(){…}()` | a handler body with the statements |

`defer` runs on every exit (fall-through, branch, return, unwind), §18.

---

## §33 Generics

**frontend** — monomorphization. Each instantiation is a distinct concrete VIR
type/function; no VIR parametric types.

---

## §34 / §49 / §50 Imports, Build Tags, Packages

| Vertex | VIR |
|---|---|
| `import "github.com/…"` | **frontend** — package resolution; not a VIR `import` |
| extern/native import | VIR `import "<platform>:<lib>" …` (§14.1, §6/§48) |
| `build amd64/arm64/windows` | profile/`target` selection (§3.1) |
| `package name` | compile-time namespace |

---

## §35 First-Class Function Types

| Vertex | VIR |
|---|---|
| `func(int32)->int32` value | `(ref $functype)` / `funcref`, or `(closure $sig)` if capturing (§19) |
| pointer param in func type | `(param (ptr …))` in `$sig` |
| calling a function value | `call_ref` (no capture) / `closure.call $sig` (capture) |

---

## §36 Anonymous Functions

| Vertex | VIR |
|---|---|
| non-capturing | top-level `func` + `func.addr`/`call_ref` |
| capturing by value | `closure.new $sig` with an env struct of copies + `closure.call` (§19) |
| writeback via `*T` param | explicit `(ptr …)` param + `*.store` |
| inline `thread`/`async`/`gpu`/`tpu` call | spawn/launch sigil on the call (§39–§40) |

---

## §37 Tuples

| Vertex | VIR |
|---|---|
| `(1, true)` / `(x:10, y:20)` | multi-value result `[t*]` or a `stack` struct |
| destructuring | multiple `local.set` |
| multi-value return | function `result` list `[t*]` |
| `()` empty tuple | `[]` (= `void`) |
| tuple over a channel | `chan` of a `stack` struct |
| tuple comparison | element-wise (frontend) |

---

## §38 Error Handling

| Vertex | VIR |
|---|---|
| `T?` | see §27 |
| `(T, E?)` tuple | multi-value + null/`has_value` error slot |
| `Result(T, E)` | **frontend** tagged `stack` struct `{ tag:i32, ok:T, err:E }` |
| `if let` / `switch` on Result | `tag` test → branch / `br_table` |
| `.try()` | branch: Err → early `return`; Ok → continue |

---

## §39–§40 Execution Sigils

| Vertex sigil | VIR |
|---|---|
| `thread f()` | `thread.new` (§16.1) |
| `async f()` | `vthread.new` (§16.1) |
| `gpu(...) f()` | `gpu.launch <funcidx>` targeting a `gpu_device` function — **(proposed §D, §E)** |
| *(proposed)* `tpu(...) f()` | `tpu.launch <funcidx>` targeting a `tpu_device` function — **(proposed §E, §F)** |

Device dispatch leads with a device-index operand (`-1` = default device);
`gpu.launch` geometry is optional (`grid`/`block` `0` = backend-chosen); both are
async. The launched function carries the single `gpu_device`/`tpu_device`
attribute — entry-vs-helper is inferred from launch sites + call graph
**(proposed §D)**. The `tpu` sigil is a proposed Vertex extension (not in 2.2).

---

## §42 Channel Dichotomy

| Vertex | VIR |
|---|---|
| value-returning spawn `let w = thread f()` | wrapper: `chan.new 1` + `chan.send` + `chan.close`; caller `chan.recv` (§16.6) |
| `w.receive()` | `chan.recv` (drop the open/closed flag) |
| `void` daemon with explicit `chan` params | pass `(ref $ct)` params; body `chan.send`/`chan.close` |

Fire-and-forget skips the wrapper — just the spawn (§16.6).

---

## §43 Channels

| Vertex | VIR |
|---|---|
| `chan T = {}` / `{cap: N}` | `chan.new $ct (i32.const 0)` / `(i32.const N)` |
| `ch.send(v)` / `ch.receive()` | `chan.send` / `chan.recv` |
| `ch.trySend(v)` → bool | `chan.trysend $ct` → `i32` — **(proposed §B)** |
| `ch.tryReceive()` → `T?` | `chan.tryrecv $ct` → `[t i32]` — **(proposed §B)** |
| `ch.close()` | `chan.close $ct` |

Reftype channel elements must be nullable (§16.4).

---

## §44 Multiplexing

| Vertex | VIR |
|---|---|
| `select { case a = t.receive(): … }` | `select_chan` with `recv` clauses (§16.5) |
| `select { … default: … }` | add a `default` clause (non-blocking) |
| polling loop | `chan.tryrecv` in a `loop`; backend yields at the back-edge **(proposed §B)** |

`select_chan` is now reserved for genuine multi-channel multiplexing; single-
channel polling uses `chan.tryrecv`.

---

## §45 State System

| Vertex | VIR |
|---|---|
| `state T` | `(pub valexpr)` source + `(sub valexpr)` endpoint (§16.7) |
| `let s: state T = {init}` | `pub.new $p <init>` |
| `s.set(v)` / `s.get()` | `pub.set $p` / `pub.get $p` |

Lossy-latest, non-blocking `set` (§16.7.3).

---

## §46 Async State Effects

| Vertex | VIR |
|---|---|
| `async func(s: state T){…}(appState)` | `pub.subscribe $p $s` + `vthread.new` running `loop { sub.recv; … }` (§15.10) |
| `.get()` on a `state T` param | `sub.get $s` |
| multiple `state T` params | one `pub.subscribe` + `sub` loop each |

---

## §47 Full Example

Lowers to the §15.10 shape: `pub.new` seeds state; `thread worker` → `thread.new`
mutating via `pub.set`; the `async` effect → `vthread.new` + `pub.subscribe` +
`sub.recv` loop. `runtime.loop()`/`runtime.exit()` are **runtime** scheduler
calls.

---

## §51 Compiler Testing

**frontend / runtime.** `test`-qualified function → ordinary `func`;
`Expected(type,"str")` → compile-time metadata driving an auto-emitted `printf`
(variadic import, §6); `build test` → a build/`target` condition. No VIR
primitive.

---

## Summary of remaining gaps

| Area | Status | Notes |
|---|---|---|
| Dynamic-array / map / string layouts | **runtime** | substrate exists (`rc`, `ptr.*`, `closure.*`); needs a `runtime_abi.md` (struct layouts, exposed functions, ownership) |
| Array growth/transform methods | **runtime** | library over the array struct |
| Maps | **runtime** | hash-map library |
| `Result`, enum associated values | **frontend** | tagged structs + branches |
| Generics | **frontend** | monomorphization |
| `var` heap string | **frontend + runtime** | a dynamic `[uint8]` |
| Quantized & dynamic-shape tensors | **UNIMPLEMENTED** | `tpu_device` v1 (proposed §F.1) |
| Multi-dim `dim3` grid/block | **TODO** | proposed §E uses 1-D extents |
| Async-join launch (`future`/`token`) | **TODO** | needs the deferred `future` type (proposed §F.1) |
| Host↔device tensor boundary on `tpu.launch` | **TODO** | `tensor` is device-only; host side needs a `buffer<shape,elem>` handle (proposed §H) |

Resolved by `proposed.md`: `chan.trysend`/`chan.tryrecv` (§B), variadic bodies
via `va.*` (§C), the unified `gpu_device`/`tpu_device` attribute + inferred
entry/helper (§D), `gpu.launch`/`tpu.launch` device dispatch (§E), the
`tensor`/`hlo.*` sub-IR (§F), and the `rc.retain`/`rc.release` + `deinit`
lifecycle that gives `.new()`/`.delete()` a concrete target (§A).