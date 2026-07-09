# Vertex Language Reference: FFI & Native Interop

## Specification 2.3 — Semantics & Rationale

Companion to `ffi.md`, same section numbers. Includes the same code as `ffi.md` plus the reasoning behind each form. Aligned with Ownership & Access (Spec 2.5) and Foundation & Data Layout (Spec 2.7), whose guarantees it extends up to — but not across — the C boundary.

**The trust model.** Everything in Specs 2.5 and 2.7 is *proved*. Nothing on the far side of a C call can be. The design goal of the FFI is therefore not to make C safe — that's impossible — but to make the unproved region as small, as legible, and as auditable as possible, and to re-establish the proofs at the exact instruction where control returns. Three principles fall out:

1. **Quarantined assertion.** A boundary declaration (§5) is an *assertion* of a C prototype, not a checked fact. A wrong assertion is undefined behavior — the **only** UB in the language — and it can occur in exactly one lexical location: inside a flat ABI namespace. Everything outside those classes retains the full 2.5/2.7 guarantee set. Auditing a Vertex program's unsafety means reading its ABI classes, nothing else.
2. **Marshal at the edge, native in the interior.** Vertex values keep their native layouts everywhere except the boundary instruction itself. Where C's representation differs (NUL-terminated strings), the conversion happens at the call, is paid at the call, and appears in the cost table. Where representations coincide (pointers, machine integers, views), the cost is zero and nothing is emitted.
3. **Foreign resources are linear.** The compiler cannot see a C resource's destructor, so it refuses to invent one. An opaque handle must be *explicitly consumed* — moved to a destroy function or entrusted to a wrapper class — before its name dies. Leaks of foreign resources are compile errors, not runtime mysteries.

---

## 1. Library Linking

```vertex
import "lib/sdl2"
import "dynamic/lib/cuda"
```

`import` remains a compile-time-only construct (2.7 §15). The `lib/` prefix requests **static or link-time binding**: symbols resolve at link, and an undeclared or missing symbol is a link error — the failure happens before the program exists. The `dynamic/` prefix requests **load-time binding**: the library is opened at program start and all declared symbols are resolved eagerly, so a missing symbol fails at load, once, with a name — never mid-frame at first call.

Eager resolution was chosen over lazy (`dlsym`-on-first-call) deliberately: lazy binding converts a deployment error into a latent runtime trap that fires on whichever code path happens to touch the symbol first. Fail-fast is the FFI's version of the marking principle — the failure surfaces where the *cause* is (the environment), not where the symptom is (the call). Per-symbol optional loading for plugin-style APIs is a Known Obligation.

---

## 2. Opaque Handles — `unique`

```vertex
type SDL_Window = unique
```

**Layout:** one machine word, never null — bit-identical to a class handle (2.7 §5). The C library allocated the object; Vertex holds only the pointer and asserts nothing about what it points to. That opacity is the point: there is no field access, no dereference syntax, no size. The handle exists solely to be *owned*.

**Absorbed into the ladder.** A `unique` handle takes the full shared / `mut` / `own` ladder like any class: Move Invalidation (2.5 §3.5) applies, exclusivity checks (2.5 §9) apply, conditional-move analysis (2.5 §7) applies. None of this requires the compiler to understand SDL — the ownership system operates on *names and pathways*, and a one-word opaque handle is the minimal thing that has both.

**Linearity — the must-consume rule.** A class has a `deinit` the compiler can call at scope exit. A `unique` handle has none — its destructor is some C function the compiler cannot identify. So the rule is: **a live `unique` handle whose name dies without being moved is a compile error** (`error: foreign handle 'w' dropped without being consumed`). The two discharges are moving it to an `own` parameter (§6 — the destroy call) and moving it into a field of a class whose `deinit` consumes it (§7). This is linear typing, but only where the compiler genuinely has no cleanup to offer; ordinary Vertex values are unaffected.

**Nullability at the return edge.** C constructors return `NULL` on failure; Vertex handles are never null. The declaration chooses the contract:

* Declared `-> SDL_Window`: the compiler inserts a null check at the return edge and **traps** on null. The assertion is "this cannot fail here."
* Declared `-> SDL_Window?`: null is the niche (2.7 §6.2), so the optional is the same single word, and `nil` *is* the C `NULL` — zero-cost, and failure flows into `if let` like any other optional.

Either way, a null pointer cannot enter the interior wearing a non-optional type. The proof boundary is re-established at the exact instruction control returns.

---

## 3. Non-Resource Pointer Shapes

| C shape | Vertex form | Lowering | Cost |
|---|---|---|---|
| `const char*` | `string` | copy to NUL-terminated temp | **O(len)** |
| `T*` (scalar out) | `mut T` | address of the local | free |
| `T**` | `-> T?` / `-> (int32, T?)` | hidden out-slot, §4 | free |
| `T*` + length | `[T]` / `mut [T]` | view's `ptr` (+ explicit `len` param) | free |

**Strings are the one paid row.** A Vertex `string` is a fat triple with no terminator (2.7 §9); C wants a NUL-terminated byte run. The compiler materializes a temporary — stack for short strings, heap above a threshold — copies the bytes, appends the NUL, passes the pointer, and destroys the temporary when the call returns. O(len), at the call, every call. This is principle 2 in action: Vertex refuses to carry a NUL terminator internally (that would tax every string to subsidize the boundary), so the boundary pays its own toll, visibly. The implied assertion: **C does not retain the pointer past the call.** A C API that stores the string needs a `clone()`-and-leak idiom or an owned-buffer declaration — a Known Obligation.

**Scalar out-params are free.** `w: mut int32` passes the address of the caller's variable directly — C's `int*` and Vertex's exclusive-access grant have the same machine shape. The exclusivity check runs as normal at the call site, which yields something C never had: while `SDL_GetWindowSize` writes through those pointers, the Law of Exclusivity guarantees no other live pathway reads them. The aliasing bugs C out-params are famous for are checked away *on the Vertex side of the wall*.

**Views decompose.** A `[T]` boundary parameter passes the view's data pointer; where the C prototype also wants a count, the declaration carries an explicit length parameter and the call site passes `xs.length`. The view's Rule 0 contract crosses intact as an assertion: C may read (or, for `mut [T]`, write in place) during the call, and must not retain the pointer. C cannot `push` — it never receives `cap` — which is the Extent Rule (2.7, principle 3) holding at the boundary: no C code ever sees an owning triple.

---

## 4. The `T**` Case

```vertex
func SDL_CreateMessage(text: string) -> SDL_Message?
func SDL_CreateMessage(text: string) -> (int32, SDL_Message?)
```

The C idiom `int f(args, T** out)` splits its result across a return value and an out-pointer. Vertex reunifies it. The compiler allocates one stack word, zeroes it, passes its address as the `T**` argument, and on return loads the word into the optional — null niche means `nil`, so no tag byte, no branch beyond the one `if let` was going to do anyway.

The first form discards the C status integer and trusts the pointer: non-null is success. The second form keeps both, returning a tuple that rides in registers (2.7 §0). Neither form is privileged; the declaration picks whichever contract the C API actually honors (some libraries return success with a null out-pointer, or failure with a partial object — the two-slot form exists for exactly those).

A non-nil result is a fresh `unique` handle and immediately carries the §2 must-consume obligation. The resource cannot be silently dropped in the failure-handling path — the compiler tracks it through `if let` arms like any other move-analyzed binding.

---

## 5. The Flat ABI Namespace

```vertex
class SDL2_API : sdl2 { ... }
```

**Not a class.** No instance, no fields, no `init`, no vtable, no allocation — the class syntax is reused (principle 6 of 2.7: no new construct where an existing one serves) to get three things: a namespace for the symbols, a lexical *audit boundary* for the assertions, and the `Namespace.symbol` call spelling that keeps every boundary crossing visually distinct from interior calls. `SDL2_API.SDL_Init(...)` lowers to a direct C call (static) or a resolved-at-load indirect call (dynamic). There is no wrapper function unless marshalling (§3) requires one, and marshalling code is inlined at the call site.

**The inheritance-position name is the link edge.** `: sdl2` binds the namespace to the imported library; a namespace whose symbols aren't in its library is a link/load error (§1).

**The assertion surface.** Each declaration inside the class asserts a C prototype: symbol name, parameter shapes, return shape, and the ownership conduct of each parameter (§6). The compiler checks Vertex call sites *against the declaration* with full 2.5 rigor — but it cannot check the declaration against the C header. Declare `own` where C doesn't free, and the interior will believe a live object is dead; declare bare where C mutates, and the Law of Exclusivity has been lied to. This is the quarantined UB of the trust model, and the flat-namespace design keeps it greppable: every unproved sentence in the program lives between one `{` and one `}`.

---

## 6. Parameter Passing Forms

The ladder crosses the boundary with its meanings intact — each keyword becomes an assertion about what the C function *does*:

| Declaration | Machine form | Assertion about C |
|---|---|---|
| `x: T` | pointer/value pass | reads only; retains nothing |
| `x: mut T` | pointer | may write the pointee; retains nothing |
| `x: own T` | pointer | takes the resource — frees it or keeps it forever |
| `x: [T]` | data pointer | reads the run; retains nothing |
| `x: mut [T]` | data pointer | writes the run in place; no growth |
| `x: func(...)` | code pointer | may store and call it (§9) |

**The destroy row needs no mechanism.** `SDL_DestroyWindow(window: own SDL_Window)` is an ordinary move (2.5 §3): bare at the call site, Move Invalidation kills the name, and the §2 linear obligation is discharged because the handle was consumed. Double-free and use-after-destroy are not "checked for" — they require naming a statically dead binding, so they are unrepresentable *in Vertex source*. This is the payoff of absorbing handles into the ownership system rather than bolting a resource tracker onto the FFI: the machinery already existed, already had its dataflow pass (2.5 §7), and foreign resources get it for free.

```vertex
SDL2_API.SDL_DestroyWindow(w.handle)
SDL2_API.SDL_RenderClear(...)          // any later use of w.handle:
                                       // error: use of moved value
```

**Exclusivity runs at boundary call sites unchanged.** `SDL_GetWindowSize(window, mut width, mut height)` counts three pathways; `mut width, mut width` would be the ordinary 2.5 §9 error. The checker does not know or care that the callee is foreign — it polices the caller's pathways, which are entirely on the proved side of the wall.

---

## 7. Wrapper Classes

```vertex
class Window {
    handle: SDL_Window
    engine: SDLEngine
}

func (w: Window) deinit() {
    SDL2_API.SDL_DestroyWindow(w.handle)
}
```

The wrapper is the idiom that converts §2's linear obligation into RAII. Storing a `unique` handle into a class field is a legal consumption: the obligation transfers to the class, and the class's `deinit` is where it must be discharged — a `deinit` that neither consumes nor forwards a `unique` field is the same compile error as §2, relocated to the one place cleanup belongs.

**Field moves in `deinit` are legal** precisely because the object is being dismantled; there is no "after" in which the hollowed field could be observed. This is the same reasoning that powers `own` receivers (2.5 §5), applied to teardown.

**Cost:** the wrapper is an ordinary class — one word to a heap object containing the handle word plus whatever else (2.7 §5). One allocation per resource at construction, zero per use: `renderer.clear()` inlines to the direct C call through one load. The wrapper adds RAII, a place for invariants, and a home for the anchor pattern (2.5 §12) if children need a back-edge — and adds no per-call machinery whatsoever.

---

## 8. Full Example

```vertex
let engine = shared(SDLEngine())

let window = Window(engine: engine, title: "My App")
let renderer = Renderer(window: window)

renderer.clear()
renderer.present()
```

Scope exit runs `deinit` in reverse declaration order (2.7 §12): `renderer`, then `window`, then `engine` releases its count. C APIs almost universally demand destruction in reverse creation order — renderers before their windows, contexts last — and reverse-declaration RAII delivers exactly that *when construction order matches dependency order*, which the constructors already force (`Renderer(window:)` cannot precede its window). The dependency discipline C documents in prose, the declaration sequence enforces by construction.

Note what is absent: no `defer SDL_DestroyRenderer(...)` lines, no cleanup section, no error-path duplication. Every resource's teardown was authored once, in §7, next to its acquisition.

---

## 9. Callbacks into C

```vertex
func on_event(code: int32) -> int32 { return 0 }
SDL2_API.SDL_SetEventFilter(on_event)
```

A boundary `func(...)` parameter is a C function pointer: one word, code address. A **non-capturing** function — named or anonymous — *is* that word (2.7 §10) and crosses at zero cost.

The deep question is lifetime: `SDL_SetEventFilter` *stores* the pointer and calls it later, long after the registering call returned. For a non-capturing function this is trivially safe — a code address has no environment, owns nothing, and is immortal. Rule 0 is not even strained: there is no access grant being stored, only code.

A **capturing** closure is another matter. It is a fat pair (2.7 §10); a C function pointer is thin. Bridging them requires either a trampoline (runtime-generated code — rejected: writable-executable pages are a security hole and break AOT targets) or a userdata pointer, which most C callback APIs provide but this declaration shape does not express. And C storing an environment pointer is precisely the stored-pathway problem Rule 0 exists to delete — the environment's liveness would rest on programmer discipline about when C might still fire the callback. The current position is that only non-capturing functions convert to boundary function pointers; the capturing form is a Known Obligation (see below, and note the grammar example's tension with 2.7 §10).

---

## The Boundary Cost Table

Extends 2.7 §16 — same pattern, same moral:

```
opaque handle (any op)        free        one word, native to the ladder
string → const char*          O(len)      copy + NUL, temp dies at return
mut scalar out-param          free        address of the local
[T] / mut [T] at boundary     free        view's ptr (+ len word)
T** out-slot                  free        one stack word, niche load
handle-returning call, T      free*       *null check → trap
handle-returning call, T?     free        null IS the niche
own destroy call              free        ordinary move, name dies
namespace call, static        free        direct C call
namespace call, dynamic       ~free       one indirection, resolved at load
non-capturing callback        free        code address
wrapper class                 O(1) once   one allocation at init
```

The FFI adds exactly one O(data) row — string marshalling — and it is the one row where C's representation and Vertex's genuinely diverge. Everything else crosses at pointer speed, because the Extent Rule and the one-word handle were chosen, back in 2.7, with this table already in mind.

---

## Known Obligations

1. **Capturing callbacks** (§9) — the grammar's closure-registration example captures `count` and mutates it, which conflicts with both capture-by-value (2.7 §10: mutating a captured `var` is a compile error) and the thin-pointer ABI. Resolve by either (a) restricting boundary callbacks to non-capturing functions and amending the grammar, or (b) adding a declared-userdata form (`func SDL_SetEventFilter(filter: func(int32) -> int32, userdata: ...)`) that splits the fat pair across C's `(fn, void*)` convention, with an explicit ownership story for the stored environment.
2. **String retention** (§3) — a C API that stores a `const char*` past the call violates the marshalling temp's lifetime. Decide between an `own string` boundary form (leaked NUL-terminated buffer, C owns it) and documenting `clone()`-and-forget.
3. **Reentrancy through callbacks** — C invoking a Vertex callback while a `mut` grant from the same frame is live creates overlapping access the per-call-site check cannot see (the same shape as 2.5 Known Obligation 5). Current lean: callbacks may not capture, so they can only touch their parameters — which may be sufficient; needs proof.
4. **Lazy / optional symbols** (§1) — plugin-style APIs want per-symbol presence tests. Candidate: declaring a symbol as `func? ` yields a load-time-resolved optional rather than a load failure.
5. **Struct-by-value at the boundary** — the current shape table covers pointers, scalars, views, and handles; C functions taking or returning small structs by value need a layout-pinning attribute (the §6.4-of-2.7 escape hatch, generalized from enums to structs) before they can be declared.
6. **Variadic C functions** — `printf`-family declarations exist in the grammar's orbit (`libc.printf`); the promotion rules (float32→double, small ints→int) and their interaction with checked conversions are unspecified.