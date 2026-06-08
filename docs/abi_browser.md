# Vertex ABI — Browser Target

A reference for all import namespaces, export conventions, and the
compilation architecture for browser-targeted Vertex modules.

---

## Architecture

The browser target does not produce a native ELF binary. It uses the same
Wasm IR pipeline as every other Vertex target, but `BrowserTarget.Emit`
writes a JS bundle instead of machine code.

```
Your Language → Wasm IR → driver.Analyze → BrowserTarget.Emit → .js bundle
```

This is the same pipeline shape as the native target:

```
Your Language → Wasm IR → driver.Analyze → x86_64Target.Emit → ELF binary
```

The IR never changes. Only the final emitter changes.

---

## Why JS, Not Raw Wasm

The DOM is not accessible from Wasm linear memory. Every DOM call —
`querySelector`, `addEventListener`, `WebSocket`, `fetch` — must cross
the Wasm/JS bridge. Staying pure Wasm means paying bridge costs on every
DOM interaction while still requiring JS glue code. You get the restricted
Wasm memory model with none of the benefits.

Compiling Wasm IR → JS instead gives you:

- Direct native API calls — `new WebSocket()`, `document.createElement()`
  with zero bridge overhead
- `ptr` translates to `ArrayBuffer` offsets instead of `add reg, r15` —
  same concept, JS emission
- `any opaque` handles resolve to native JS object references via the
  handle table — no manual pointer chasing
- `@async` maps to `async/await` or `Promise`
- `@thread` maps to Web Workers
- JSX fragments compile to `document.createElement` sequences

The Wasm IR was always Vertex's internal representation. It was never the
browser deliverable.

---

## Split Compilation

Functions with no `browser/*` imports stay compiled to `.wasm` and are
called from JS. Functions that touch `browser/*` imports go through the JS
backend. `driver.Analyze` tracks this per-function via the routing table —
the same mechanism that separates CPU and GPU functions today.

```
CPU-heavy functions      →  .wasm  (matrix math, compression, audio)
DOM / network / events   →  .js    (browser/* imports)
```

A single `build browser` module can emit both. The linker bundles them
into one deliverable.

---

## Pointer Model in the Browser

On native targets `ptr` emits `add reg, r15` — translating a Wasm linear
memory offset to a native virtual address.

On the browser target `ptr` emits an `ArrayBuffer` offset read:

```
native:   add  rsi, r15          ; linear-memory offset → native VA
browser:  buffer[offset]         ; linear-memory offset → ArrayBuffer read
```

The frontend sees the same `ptr` token. The backend owns the translation.
NULL (offset 0) passes through without the addition, matching C convention,
identical to the native library import rule.

---

## Import Path Grammar

```
"browser/websocket"    →  new WebSocket()
"browser/dom"          →  document.* / element.*
"browser/fetch"        →  fetch() / Request / Response / Headers
"browser/storage"      →  localStorage / sessionStorage
"browser/canvas"       →  HTMLCanvasElement / CanvasRenderingContext2D
"browser/audio"        →  AudioContext / AudioNode graph
"browser/worker"       →  Worker / SharedWorker
```

The emission prefix `browser/` routes the compiler to `BrowserTarget.Emit`.
Everything after it identifies the specific Web API.

---

## Import Modules

---

### `browser/websocket` — WebSocket API

Emits `new WebSocket()` and method calls on the native browser WebSocket
object. The socket instance is captured as `any opaque` — the compiler
manages it via the handle table. No bridge cost on any call.

```swift
package web_main
build browser
import "browser/websocket"

class WebSocket : websocket {
    func connect(url: any char) -> any opaque
    func send(ws: mut any opaque, data: any char)
    func onopen(ws: mut any opaque, handler: func())
    func onmessage(ws: mut any opaque, handler: func(any char))
    func onerror(ws: mut any opaque, handler: func(any char))
    func onclose(ws: mut any opaque, handler: func())
    func close(ws: mut any opaque)
    func readyState(ws: any opaque) -> int
}
```

**readyState constants:**

| Constant       | Value | Meaning     |
|----------------|-------|-------------|
| `WS_CONNECTING`| 0     | Opening     |
| `WS_OPEN`      | 1     | Ready       |
| `WS_CLOSING`   | 2     | Closing     |
| `WS_CLOSED`    | 3     | Terminated  |

---

### `browser/dom` — DOM API

Emits direct `document.*` and `element.*` calls. `any opaque` captures
native `Element` / `Event` references via the handle table.

```swift
package dom
build browser
import "browser/dom"

class Dom : dom {
    func query(selector: any char) -> any opaque?
    func queryAll(selector: any char) -> any opaque
    func create(tag: any char) -> any opaque
    func append(parent: mut any opaque, child: any opaque)
    func remove(node: mut any opaque)
    func setText(node: mut any opaque, text: any char)
    func getValue(event: any opaque) -> any char
    func addClass(node: mut any opaque, name: any char)
    func removeClass(node: mut any opaque, name: any char)
    func setAttribute(node: mut any opaque, key: any char, val: any char)
    func on(node: mut any opaque, event: any char, handler: func(any opaque))
}
```

---

### `browser/fetch` — Fetch API

Emits `fetch()` calls. Response body methods map to `async` functions —
the browser target emits `await response.json()` / `await response.text()`
at the call site.

```swift
package http
build browser
import "browser/fetch"

class Fetch : fetch {
    func get(url: any char) async -> any opaque
    func post(url: any char, body: any char) async -> any opaque
    func status(response: any opaque) -> int
    func text(response: any opaque) async -> any char
    func json(response: any opaque) async -> any opaque
}
```

---

### `browser/storage` — Storage API

Emits `localStorage.*` / `sessionStorage.*` calls directly.

```swift
package storage
build browser
import "browser/storage"

class Storage : storage {
    func localGet(key: any char) -> any char?
    func localSet(key: any char, val: any char)
    func localRemove(key: any char)
    func sessionGet(key: any char) -> any char?
    func sessionSet(key: any char, val: any char)
    func sessionRemove(key: any char)
}
```

---

## Export Suffix — Browser Concurrency

| Suffix     | JS emission            | Kernel primitive  |
|------------|------------------------|-------------------|
| `@async`   | `async/await`          | Promise           |
| `@thread`  | `new Worker()`         | Web Worker        |

`@process` is not available on the browser target — `fork(2)` has no
browser equivalent. The compiler errors if `@process` is used with
`build browser`.

---

## JSX Fragment Syntax

A function returning `Element` may use `<></>` fragment syntax in its
return expression. The compiler emits `document.createElement` sequences.
Fragments add no wrapper node to the DOM.

**Expressions inside `{}` are any valid Vertex expression:**

```swift
{state.status}               // string value
{count > 0}                  // bool
{for msg in messages { }}    // loop — emits mapped element sequence
{status == "open" ? "●" : "○"}  // ternary
```

**Event handlers follow the same `func()` rules as everywhere else:**

```swift
onClick={func() { ws.send(sock: &sock, data: state.input.any()) }}
onInput={func(e: any opaque) { state.input = dom.getValue(e) }}
```

No special event syntax. No synthetic event system. Native browser events
passed through the handle table as `any opaque`.

---

## Full Example — `web_main.vs`

```swift
package web_main
build browser

import "browser/websocket"
import "browser/dom"

class WebSocket : websocket {
    func connect(url: any char) -> any opaque
    func send(ws: mut any opaque, data: any char)
    func onopen(ws: mut any opaque, handler: func())
    func onmessage(ws: mut any opaque, handler: func(any char))
    func onerror(ws: mut any opaque, handler: func(any char))
    func onclose(ws: mut any opaque, handler: func())
    func close(ws: mut any opaque)
    func readyState(ws: any opaque) -> int
}

let WS_CONNECTING = 0
let WS_OPEN       = 1
let WS_CLOSING    = 2
let WS_CLOSED     = 3

struct ChatState {
    var status:   string
    var messages: [string]
    var input:    string
}

func ChatApp(url: string) -> Element {

    var state = ChatState{
        status:   "connecting",
        messages: [],
        input:    "",
    }

    var ws   = WebSocket()
    var sock: any opaque = ws.connect(url.any())

    ws.onopen(sock: &sock, handler: func() {
        state.status = "connected"
    })

    ws.onmessage(sock: &sock, handler: func(raw: any char) {
        state.messages += [string(raw)]
    })

    ws.onerror(sock: &sock, handler: func(reason: any char) {
        state.status = "error: " + string(reason)
    })

    ws.onclose(sock: &sock, handler: func() {
        state.status = "disconnected"
    })

    defer ws.close(sock: &sock)

    return (
        <>
            <div class="chat-root">

                <header class="chat-header">
                    <h1>{"Live Chat"}</h1>
                    <span class={"status " + state.status}>
                        {state.status}
                    </span>
                </header>

                <ul class="message-list">
                    {for msg in state.messages {
                        <li class="message">{msg}</li>
                    }}
                </ul>

                <footer class="chat-footer">
                    <input
                        type="text"
                        placeholder="Type a message…"
                        value={state.input}
                        onInput={func(e: any opaque) {
                            state.input = dom.getValue(e)
                        }}
                    />
                    <button
                        disabled={ws.readyState(sock) != WS_OPEN}
                        onClick={func() {
                            if state.input != "" {
                                ws.send(sock: &sock, data: state.input.any())
                                state.input = ""
                            }
                        }}
                    >
                        {"Send"}
                    </button>
                </footer>

            </div>
        </>
    )
}
```

---

## Compilation Flow — Annotated

```
web_main.vs
    │
    ▼
Wasm IR                         ← frontend emits spec-compliant .wasm
    │
    ▼
driver.Analyze                  ← parses browser/* import paths
    │                             builds routing table per function
    │                             sets ctx.NeedsBrowserRuntime
    │
    ├── CPU-heavy functions      → stay as .wasm
    │       (no browser/* imports)
    │
    └── DOM / network functions  → BrowserTarget.Emit
            (browser/* imports)         │
                                        ▼
                                   .js bundle
                                        │
                                   ptr  →  ArrayBuffer offset
                                   any opaque  →  handle table ref
                                   @async      →  async / await
                                   @thread     →  new Worker()
                                   <></>       →  createElement sequence
                                   defer       →  component cleanup hook
```

The Wasm IR is the same at every stage. `BrowserTarget.Emit` is the only
thing that differs from the native path.

---

## Constraints

- `@process` is not valid with `build browser` — no `fork(2)`.
- `linux/kernel/syscalls` imports are a compile error with `build browser`.
- `memory.heap.*` / `memory.arena.*` back onto an ArrayBuffer-side bump
  allocator injected by the driver — same import surface, JS emission.
- `malloc` and `free` remain compile-time errors — use `memory.*` as on
  native.
- Floating-point in JSX expression position is formatted via the JS
  runtime's default `toString` — explicit formatting is the caller's
  responsibility.