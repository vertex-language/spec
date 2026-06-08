# Vertex ABI — Android Target

A reference for all import namespaces, export conventions, and the
compilation architecture for Android-targeted Vertex modules.

---

## Architecture

The Android target does not produce a native ELF binary. It uses the same
Wasm IR pipeline as every other Vertex target, but `AndroidTarget.Emit`
writes JVM bytecode instead of machine code. ART (Android Runtime) consumes
the bytecode directly.

```
Your Language → Wasm IR → driver.Analyze → AndroidTarget.Emit → JVM bytecode → ART
```

This is the same pipeline shape as every other target:

```
Your Language → Wasm IR → driver.Analyze → x86_64Target.Emit  → ELF binary
Your Language → Wasm IR → driver.Analyze → BrowserTarget.Emit → .js bundle
Your Language → Wasm IR → driver.Analyze → AndroidTarget.Emit → JVM bytecode
```

The IR never changes. Only the final emitter changes.

---

## Mental Model

Kotlin proved you do not need the NDK to build a first-class Android app.
You write Kotlin, the compiler emits JVM bytecode, ART runs it, and you get
full access to every Android API — Activity, Compose, ViewModel, Coroutines.
The native layer never enters the picture.

Vertex follows the same model:

```
Kotlin (.kt)  → Kotlin IR   → JVM bytecode → ART
Vertex (.vs)  → Wasm IR     → JVM bytecode → ART
```

Vertex's Wasm IR plays the same role Kotlin IR plays. JVM bytecode is the
delivery format ART consumes — an implementation detail of the compiler
pipeline, not a target you think about when writing Android code.

The NDK path is not a goal. It is the old way — valid when you have no
choice, not the model Vertex targets.

---

## Pointer Model on Android

On native targets `ptr` emits `add reg, r15` — a linear memory offset
translated to a native virtual address.

On the Android target `ptr` emits a JVM byte array index read:

```
native:   add  rsi, r15          ; linear-memory offset → native VA
browser:  buffer[offset]         ; linear-memory offset → ArrayBuffer read
android:  byteArray[offset]      ; linear-memory offset → JVM byte[] read
```

The frontend sees the same `ptr` token. The backend owns the translation.

`any opaque` captures JVM object references via the handle table — the same
mechanism the browser target uses for DOM element references. The compiler
manages it automatically. The `.vs` layer sees `any opaque` and nothing else.

---

## Import Path Grammar

```
"android/view"          →  android.view.*
"android/compose"       →  androidx.compose.*
"android/activity"      →  android.app.Activity / ComponentActivity
"android/viewmodel"     →  androidx.lifecycle.ViewModel
"android/navigation"    →  androidx.navigation.*
"android/room"          →  androidx.room.*  (local database)
"android/network"       →  android.net.* / okhttp3.*
"android/websocket"     →  okhttp3.WebSocket
"android/storage"       →  SharedPreferences / DataStore
"android/permission"    →  ActivityResultLauncher / permission APIs
"android/notification"  →  NotificationManager / NotificationCompat
"android/camera"        →  androidx.camera.*
"android/sensor"        →  android.hardware.SensorManager
```

The emission prefix `android/` routes the compiler to `AndroidTarget.Emit`.
Everything after it identifies the specific Android or AndroidX API.
The compiler resolves each import to its JVM class and method at emit time.

---

## Import Modules

---

### `android/activity` — Activity Lifecycle

Emits `ComponentActivity` subclass wiring. Lifecycle callbacks map directly
to the standard Android Activity lifecycle. The compiler generates the
correct JVM class structure and registers each callback at the right
lifecycle hook.

```swift
package main_activity
build android
import "android/activity"

class Activity : activity {
    func onCreate(act: mut any opaque, savedState: any opaque?)
    func onStart(act: mut any opaque)
    func onResume(act: mut any opaque)
    func onPause(act: mut any opaque)
    func onStop(act: mut any opaque)
    func onDestroy(act: mut any opaque)
    func setContent(act: mut any opaque, root: any opaque)
    func finish(act: mut any opaque)
    func getIntent(act: any opaque) -> any opaque
    func startActivity(act: mut any opaque, intent: any opaque)
}
```

---

### `android/compose` — Jetpack Compose

Emits `@Composable` annotated JVM functions. The compiler marks each
function that returns `Element` with the correct Compose runtime annotation
at the JVM bytecode level — invisible to the `.vs` layer.

```swift
package ui
build android
import "android/compose"

class Compose : compose {
    func text(value: any char)
    func button(label: any char, onClick: func())
    func column(content: func())
    func row(content: func())
    func box(content: func())
    func spacer(weight: float)
    func modifier() -> any opaque
    func fillMaxSize(mod: any opaque) -> any opaque
    func fillMaxWidth(mod: any opaque) -> any opaque
    func padding(mod: any opaque, dp: int) -> any opaque
    func background(mod: any opaque, color: int) -> any opaque
    func clickable(mod: any opaque, handler: func()) -> any opaque
    func lazyColumn(items: any opaque, row: func(any opaque))
    func textField(
        value: any char,
        onValueChange: func(any char),
        placeholder: any char
    )
    func state(initial: any opaque) -> any opaque
    func rememberState(value: any opaque) -> any opaque
}
```

---

### `android/viewmodel` — ViewModel + StateFlow

Emits `ViewModel` subclass wiring and `StateFlow` / `MutableStateFlow`
bindings. `@async` functions inside a ViewModel context emit inside
`viewModelScope.launch` — the compiler infers the scope from context.

```swift
package vm
build android
import "android/viewmodel"

class ViewModel : viewmodel {
    func stateFlow(initial: any opaque) -> any opaque
    func updateState(flow: mut any opaque, value: any opaque)
    func collectState(flow: any opaque, handler: func(any opaque))
    func launch(vm: any opaque, block: func() async)
    func onCleared(vm: mut any opaque, handler: func())
}
```

---

### `android/websocket` — OkHttp WebSocket

Emits `OkHttpClient` and `WebSocket` JVM calls via the OkHttp library,
which is the standard WebSocket implementation on Android. The socket
instance is captured as `any opaque` via the handle table.

```swift
package ws
build android
import "android/websocket"

class WebSocket : websocket {
    func connect(url: any char) -> any opaque
    func send(ws: mut any opaque, data: any char)
    func onopen(ws: mut any opaque, handler: func())
    func onmessage(ws: mut any opaque, handler: func(any char))
    func onerror(ws: mut any opaque, handler: func(any char))
    func onclose(ws: mut any opaque, handler: func())
    func close(ws: mut any opaque)
}
```

---

### `android/network` — HTTP

Emits OkHttp `Call` and `Response` JVM calls. Async functions emit inside
the OkHttp async callback model, surfaced to Vertex as standard `@async`.

```swift
package http
build android
import "android/network"

class Http : network {
    func get(url: any char) async -> any opaque
    func post(url: any char, body: any char) async -> any opaque
    func status(response: any opaque) -> int
    func text(response: any opaque) async -> any char
    func json(response: any opaque) async -> any opaque
}
```

---

### `android/room` — Local Database

Emits Room DAO and Database JVM class wiring. Query results surface as
`any opaque` — the handle table holds the typed Room entity reference.

```swift
package db
build android
import "android/room"

class Room : room {
    func database(name: any char, schema: any opaque) -> any opaque
    func query(db: any opaque, sql: any char) async -> any opaque
    func insert(db: any opaque, entity: any opaque) async -> int
    func update(db: any opaque, entity: any opaque) async -> int
    func delete(db: any opaque, entity: any opaque) async -> int
    func observe(db: any opaque, query: any char, handler: func(any opaque))
}
```

---

### `android/storage` — Preferences + DataStore

Emits `SharedPreferences` and Jetpack `DataStore` JVM calls.

```swift
package prefs
build android
import "android/storage"

class Storage : storage {
    func getString(key: any char) -> any char?
    func putString(key: any char, value: any char)
    func getInt(key: any char) -> int?
    func putInt(key: any char, value: int)
    func getBool(key: any char) -> bool?
    func putBool(key: any char, value: bool)
    func remove(key: any char)
    func observe(key: any char, handler: func(any opaque))
}
```

---

### `android/navigation` — Navigation Component

Emits Jetpack Navigation `NavController` and `NavHost` JVM wiring.
Routes are declared as string identifiers — the compiler validates
uniqueness at emit time.

```swift
package nav
build android
import "android/navigation"

class Navigation : navigation {
    func controller() -> any opaque
    func navigate(ctrl: mut any opaque, route: any char)
    func navigateBack(ctrl: mut any opaque)
    func navHost(
        ctrl: any opaque,
        start: any char,
        routes: func()
    )
    func composable(route: any char, content: func())
    func currentRoute(ctrl: any opaque) -> any char?
}
```

---

## Export Suffix — Android Concurrency

| Suffix   | JVM emission                          | Scope                  |
|----------|---------------------------------------|------------------------|
| `@async` | `viewModelScope.launch` / `suspend`   | Coroutine              |
| `@thread` | `Executors.newSingleThreadExecutor()` | Background thread      |

`@process` is not valid with `build android`.
`@thread` should be avoided for UI work — use `@async` which marshals
back to the main thread automatically via the coroutine dispatcher.

---

## JSX Fragment Syntax on Android

A function returning `Element` uses the same `<></>` fragment syntax as
the browser target. On Android, `BrowserTarget.Emit` is replaced by
`AndroidTarget.Emit` — fragments compile to `@Composable` function calls
instead of `document.createElement` sequences.

The `.vs` syntax is identical across both targets. The backend owns the
difference.

```swift
// browser target  →  document.createElement("div")
// android target  →  Column { }  /  Box { }  /  Row { }
```

Event handlers follow the same `func()` rules as everywhere else —
the Android target emits the correct Compose lambda at the JVM level.

---

## Full Example — `chat_screen.vs`

```swift
package chat_screen
build android

import "android/compose"
import "android/websocket"
import "android/viewmodel"
import "android/navigation"

class Compose   : compose   { /* — see android/compose above  — */ }
class WebSocket : websocket { /* — see android/websocket above — */ }
class ViewModel : viewmodel { /* — see android/viewmodel above — */ }

let WS_OPEN = 1

struct ChatState {
    var status:   string
    var messages: [string]
    var input:    string
}

func ChatScreen(url: string, navCtrl: any opaque) -> Element {

    var state = ChatState{
        status:   "connecting",
        messages: [],
        input:    "",
    }

    var vm  = ViewModel()
    var ws  = WebSocket()
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

    vm.onCleared(vm: vm, handler: func() {
        ws.close(sock: &sock)
    })

    return (
        <>
            <Column modifier={Compose().fillMaxSize(Compose().modifier())}>

                <Row modifier={Compose().fillMaxWidth(Compose().modifier())}>
                    <Text>{"Live Chat"}</Text>
                    <Spacer weight={1.0}/>
                    <Text>{state.status}</Text>
                </Row>

                <LazyColumn
                    modifier={Compose().fillMaxWidth(Compose().modifier())}
                    items={state.messages}
                    row={func(msg: any opaque) {
                        <Text>{string(msg)}</Text>
                    }}
                />

                <Row modifier={Compose().fillMaxWidth(Compose().modifier())}>
                    <TextField
                        value={state.input}
                        onValueChange={func(v: any char) {
                            state.input = string(v)
                        }}
                        placeholder={"Type a message…"}
                    />
                    <Button
                        label={"Send"}
                        onClick={func() {
                            if state.input != "" {
                                ws.send(sock: &sock, data: state.input.any())
                                state.input = ""
                            }
                        }}
                    />
                </Row>

            </Column>
        </>
    )
}
```

---

## Compilation Flow — Annotated

```
chat_screen.vs
    │
    ▼
Wasm IR                         ← frontend emits spec-compliant .wasm
    │
    ▼
driver.Analyze                  ← parses android/* import paths
    │                             builds routing table per function
    │                             sets ctx.NeedsAndroidRuntime
    │
    └── AndroidTarget.Emit
            │
            ▼
       JVM bytecode
            │
       ptr  →  byte[] index
       any opaque  →  handle table → JVM object ref
       @async      →  suspend / viewModelScope.launch
       @thread     →  Executors.newSingleThreadExecutor()
       <></>       →  @Composable function calls
       defer       →  ViewModel.onCleared hook
            │
            ▼
       .apk / .aab                ← Android toolchain (d8 / R8)
            │
            ▼
       ART                        ← Android Runtime
```

The Wasm IR is the same at every stage. `AndroidTarget.Emit` is the only
thing that differs from the native or browser path.

---

## Constraints

- `@process` is not valid with `build android`.
- `linux/kernel/syscalls` imports are a compile error with `build android`.
- `memory.heap.*` backs onto a JVM byte array allocator injected by the
  driver — same import surface, JVM emission.
- `malloc` and `free` remain compile-time errors — use `memory.*` as on
  every other target.
- UI mutations must occur on the main thread. `@async` handles this
  automatically via the coroutine dispatcher. Raw `@thread` functions
  that mutate Compose state are undefined behavior.
- `build android` and `build browser` are mutually exclusive per file.
  Use the filename suffix convention for multi-platform packages:
  `chat_screen_android.vs` / `chat_screen_browser.vs`.