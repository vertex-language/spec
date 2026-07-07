# `vs.lib` — Native Library Manifest

## Status

Companion spec to `spec.md` (`vs.mod`) and the Vertex Language Grammar
(`README.md`). Defines how a Vertex package wraps a native C/C++
library: fetching/verifying the artifact, linking it, and exposing its
symbols to Vertex code.

`build.vs` (imperative build wiring for foreign build systems — CMake,
Bazel, etc.) is out of scope here; it's reserved for libraries that
don't fit the declarative provider/target model below.

---

## 1. Relationship to `vs.mod`

`vs.lib` doesn't change `vs.mod`. `require` still resolves pure Vertex
dependencies via ordinary version selection, with no branching on OS,
arch, or package manager (`spec.md` §3 unchanged):

```
require (
    github.com/someone/vertex-http v0.3.1
    github.com/username/sqlite3    v2.1.0
)
```

There's no special "native" syntax. The resolver discovers nativeness
lazily: when a required module is fetched, the compiler checks its root
for a `vs.lib`. If present, it's a **native-wrapper package** and the
described artifact is fetched/verified/built as part of satisfying that
requirement. If absent, resolution proceeds as normal.

---

## 2. One `vs.lib` Per Folder

A folder with a `vs.lib` is a native-wrapper package, alongside its own
ordinary `vs.mod`:

```
sqlite3/                       (= github.com/username/sqlite3)
├── vs.mod
├── vs.lib
├── raw.vs
└── db.vs
```

Exactly one `vs.lib` per folder — two native libraries split into two
sibling modules, same as two Rust `-sys` crates never sharing one.

Since the wrapper is a normal module, ordinary version selection
applies for free: if two dependents require the same wrapper at
different versions, single-version-per-module-path resolution picks
one, which also guarantees at most one provider of the same native
symbols per build. No separate duplicate-linkage check needed.

---

## 3. Grammar

One structural unit: a **provider** listing **targets**. Nothing grows
per provider kind — variation is governed by §5's rules, not new syntax.

```
VsLib    = { Meta } { Provider } .

Meta     = Library
         | Field .

Library  = "library" ImportPath newline .

ImportPath = PathSegment { "/" PathSegment } .   // same lexical class
                                                  // as vs.mod's module
                                                  // path (spec.md §2) —
                                                  // bare, unquoted

Provider = "provider" Kind "{" newline
               { Field }                          // provider-level defaults
               { Target }
           "}" newline .

Kind     = "apt" | "dnf" | "pacman" | "brew" | "vcpkg" | "fetch" | ident .

Target   = "target" string [ "release" string ] "{" newline
               { Field }
           "}" newline .

Field    = ident "=" string newline .
```

A `Target`'s first string is a build tag — `Arch "-" OsTag`:

```
Tag   = Arch "-" OsTag .
Arch  = "amd64" | "arm64" .
OsTag = "linux" | "darwin" | "windows" .
```

These are exactly the arch/platform tags `build <tag>` recognizes
(`README.md` §49) — one vocabulary for the whole language.

The optional `release` string after a target tag qualifies it to a
specific host release (§5 Rule 4). An unrecognized `Kind` (the `ident`
arm) still parses but has no built-in resolver — deferred to `build.vs`
or future compiler support, like an unrecognized `format` (§6).

---

## 4. Top-Level Metadata

| Field | Required | Meaning |
|---|---|---|
| `library` | yes | Import path of the wrapped library, written bare like `vs.mod`'s `module` line — e.g. `library github.com/username/sqlite3`. Not quoted, not an `ident "=" string` `Field`; it's its own line kind. |
| `version` | yes | The wrapper's pinned *intended* upstream version, independent of the wrapping module's own Vertex semver. |
| `description` | no | Free text. |

**The canonical name is the import path's final segment**, exactly as
a module's package name is conventionally its path's final segment.
`library github.com/username/sqlite3` yields the canonical name
`sqlite3`. That derived name is:

- the fallback `link` value (§6) when no `link` Field is set anywhere;
- the name that must equal the final segment of any `lib/<name>`
  import mounting this wrapper (§8).

There is no separate `name = "..."` field to keep in sync with the
path — writing the full path once, the same way `vs.mod` identifies a
module, is the single source of truth. (For the common case where a
`vs.lib`'s wrapper module *is* the library's own dedicated module, as
in §2's layout, `library`'s path is typically identical to that
folder's `vs.mod` `module` line — but nothing enforces that identity;
`library` only has to name the thing being wrapped.)

**`version` is documentary, not verified.** Neither resolution (§7) nor
verification (§9) checks an artifact against `version` — `hash` only
confirms a fetch matches what was pinned at authoring time; it can't
catch the wrong artifact pinned under the right hash. This matters most
for managed providers, where `package =` resolves live against a system
index decoupled from both `version` and `raw.vs`.

Where a provider can report a resolved version (a live query, or a
version embedded in a `fetch` URL), tooling SHOULD warn on mismatch
against the declared `version`. This is advisory only — index drift is
expected, not a violation.

---

## 5. The Provider Model

A `provider` block describes one way to obtain the library. Multiple
providers are tried in file order (§7). Fields at provider level are
defaults; each target may override.

| Kind | Source | Valid `OsTag` |
|---|---|---|
| `apt` | host package index (`.deb`) | `linux` |
| `dnf` | host package index (`.rpm`) | `linux` |
| `pacman` | host package index | `linux` |
| `brew` | host package index (bottle) | `darwin`, `linux` (Linuxbrew) |
| `vcpkg` | vcpkg, building its own binaries | `windows`, `linux`, `darwin` |
| `fetch` | direct HTTPS (GitHub Release, S3/CDN, any static host) | any |

`apt`/`dnf`/`pacman`/`brew` are **managed**: the index *is* the source.
`vcpkg` builds from its own triplet vocabulary. `fetch` is a plain
download with no index. Every kind resolves against something
independently fetchable and verifiable from the file alone.

Five rules govern the whole model:

**Rule 1 — Defaults flow down; `hash` never defaults.**
Any `Field` at provider level is a default for its targets, overridable
per target. The exception is `hash`: it's bound to one artifact and
never inherited — it sits exactly where the pinned bytes are produced
(Rule 2). This is the security invariant: every distinct blob carries
its own pin.

**Rule 2 — `url` placement sets artifact granularity; `hash` travels with `url`.**

| `url` location | Artifact granularity | `hash` location |
|---|---|---|
| provider level | one shared artifact, fetched/extracted once; targets locate a file within it | provider level |
| per target | one artifact per target, fetched independently | per target |
| absent (managed kinds) | index is the source; inherently per-target | per target |

A `hash` placed to contradict the `url`'s placement (e.g. a per-target
`hash` under a provider-level `url`) is a validation error.

**Rule 3 — `lib`'s shape picks the match mode.**
`lib` names the library file to link:
- **Contains a path separator** → exact relative path from the artifact
  root. Needed when one archive holds multiple platforms in sibling
  folders sharing basenames (`linux-x64/lib/libfoo.so` vs
  `linux-arm64/lib/libfoo.so`).
- **Bare basename** → matched anywhere in the extracted/installed tree,
  must resolve to exactly one file. Suited to package-manager trees
  whose layout the author doesn't control.

In both modes the final path component may resolve through a symlink
chain (e.g. `libsqlite3.so.0` → `libsqlite3.so.0.8.6`). An ambiguous
basename, or a path with nothing at it, is a resolve-time error —
switch to the path form.

**Rule 4 — `release` is a finer target key, resolved by specificity.**
A target may carry `release "ubuntu-22.04"`. Among targets matching the
host's arch-os, the most specific wins: a release match beats an
unqualified catch-all. Ties break by file order.

`release` is `<distro-id>-<version>`, lowercase, matching
`/etc/os-release`'s `ID`/`VERSION_ID`, or the nearest equivalent
(Fedora's `VERSION_ID` for `dnf`, macOS product version for `brew`).
Release variance is real — package names and SONAMEs shift (e.g. major
OpenSSL bumps rename `libssl1.0.0` to `libssl1.1`), and `brew` bottles
are commonly built per macOS release.

Two safe authoring stances:
- **Strict enumeration** — only release-qualified targets, no catch-all.
  A non-matching host release is a hard resolve-time error, no fallback.
- **Explicit default** — add an unqualified catch-all, used only when no
  release-qualified target matches.

A shared artifact (provider-level `url`) is one blob and can't vary by
release — a `release` qualifier there is rejected.

**Rule 5 — Each kind has a valid OS set; an impossible target is an error.**
`apt`/`dnf`/`pacman` are Linux-only; `brew` is macOS + Linuxbrew;
`vcpkg` is cross-platform. Valid sets are §5's table. A kind/OsTag
mismatch (e.g. `dnf` targeting `windows`) is a resolve-time error — a
caught typo, not dead config.

---

## 6. Fields

| Field | Kinds | Level | Meaning |
|---|---|---|---|
| `link` | all | provider default / target | The `-l<name>` linker arg. Defaults to the canonical name derived from `library` (§4) if omitted. |
| `package` | managed | provider default / target | Package name as that manager names it. |
| `url` | `fetch`; any target pinning exact bytes | provider or target (Rule 2) | Direct HTTPS URL. No index. |
| `format` | `fetch` | provider (shared) / target | Archive format, extracted once `hash` verifies raw bytes. |
| `hash` | all | follows the artifact (Rule 2) | `h1:<sha256-hex>` of raw fetched bytes (§9.1). |
| `lib` | all | provider default / target | Library file to link (Rule 3). |
| `vcpkg_triplet` | `vcpkg` | target | vcpkg's own triplet vocabulary. |

**`package =` resolves live** against the system's configured index —
convenient, only as reproducible as that index. For point-in-time
reproducibility, add `url =` on a managed target pinning an exact
archived artifact (e.g. a Debian snapshot URL); `hash` still applies
(an ordinary case of Rule 2: per-target `url` ⇒ per-target artifact).

**`vcpkg_triplet` ≠ the target selector string.** The tag
(`"amd64-windows"`) is our selection key, matching `build` tags.
`vcpkg_triplet` is vcpkg's own vocabulary, additionally distinguishing
static/dynamic CRT variants (`x64-windows-static-md` vs
`x64-windows-static`) our selector doesn't model — don't collapse them.
`vcpkg` builds its own binaries, so it has no host-release axis:
`release` isn't used with `vcpkg`.

**Recognized `format` values:**

| `format` | Contents |
|---|---|
| `zip` | zip |
| `tar` | uncompressed tar |
| `tar.gz` / `tgz` | gzip tar |
| `tar.bz2` / `tbz2` | bzip2 tar |
| `tar.xz` / `txz` | xz tar |
| `tar.zst` | zstd tar |
| `7z` | 7-Zip |

This is the built-in extractor set. `format` is an ordinary `Field`, so
other strings parse but have no extraction support until the compiler
adds it, or it's handled via `build.vs`.

---

## 7. Resolution Order

1. In file order, take the **first provider block** with any target
   matching the build's `Arch`-`OsTag` (with a valid OS for the kind,
   Rule 5). First match wins — no "best available" heuristic.
2. Within it, among matching targets, select the **most specific by
   release** (Rule 4).
3. If that arch-os has release-qualified targets but none matches the
   host, and there's no catch-all, that provider **fails outright** —
   no fallthrough to the next provider.
4. If no provider has any matching target, it's a hard compile error.
   No silent fallback, no silent skip.

Provider order is meaningful policy: `apt` before `fetch` means "prefer
the system-package route, fall back to fetch only if `apt` has no entry
for this target." Reordering flips the preference with no other change.

---

## 8. Import Resolution — `lib/<name>`

Mirrors `README.md` §48.1's `dynamic/lib/` convention, as its link-time
counterpart:

| Prefix | Resolved | Mechanism |
|---|---|---|
| `lib/<name>` | compile/link time | `vs.lib` in the current module is fetched and built; compiler links the result. |
| `dynamic/lib/<name>` | runtime | `dlopen`/`dlsym` or `LoadLibrary`/`GetProcAddress` against whatever the host has. No fetch. |

`lib/<name>` isn't a module-graph coordinate the way `import
"github.com/..."` is — no host, no version. It resolves against the
sibling `vs.lib` in the same module only. No matching `vs.lib` is a
compile error.

**Naming consistency** — three things must agree (as `README.md` §48
already requires for native bindings generally):

```
vs.lib:               library github.com/username/sqlite3
                            ↓ (final path segment)
import:                "lib/sqlite3"            ← last segment == library's last segment
                            ↓
class binding:          class Sqlite3 : sqlite3 ← tag == import's last segment
```

---

## 9. Verification

### 9.1 Hash format

A `hash` is `h1:<hex>` — `h1` denotes SHA-256, `<hex>` lowercase. The
hashed content is the **raw fetched bytes exactly as transferred**
(`.deb`, `.rpm`, bottle, vcpkg binary, downloaded archive) — never an
extracted or repacked form. Two logically-identical but byte-different
artifacts (different compression, embedded timestamps, mirror
repackaging) will *not* share a `hash`, even with identical installed
contents. Pin against the specific bytes fetched, not "the package" in
the abstract.

### 9.2 What gets checked

- **Per-target artifacts** (managed kinds, `vcpkg`, `fetch` with
  per-target `url`): the per-target `hash` is checked before trust.
- **Shared artifacts** (`fetch` with provider-level `url`): the single
  provider-level `hash` is checked once against the raw archive
  (§9.1), before extraction — never after. Then `format` extracts, and
  each target's `lib` is located in the tree.
- **`lib` location** is a second, independent per-target check (Rule
  3): does the artifact contain the declared path, or a unique file at
  the declared basename? A hash match with no resolvable `lib` is still
  a resolve-time error.

---

## 10. The Wrapper Pattern

A native-wrapper module typically separates a raw FFI surface from an
idiomatic Vertex API — both ordinary top-level declarations, both
importable directly since there's no visibility keyword yet (§12).
Exporting the raw binding alongside or instead of the wrapper is valid,
useful for consumers wanting closer-to-the-metal access.

```vertex
// raw.vs
package sqlite3

import "lib/sqlite3"

class Sqlite3 : sqlite3 {
    func sqlite3_open(filename: *const char, db: **void) -> int32
    func sqlite3_close(db: *void) -> int32
    func sqlite3_exec(db: *void, sql: *const char, cb: *void, arg: *void, errmsg: **char) -> int32
}
```

```vertex
// db.vs
package sqlite3

class Sqlite3DB {
    raw:    Sqlite3
    handle: *void
}

func (s: Sqlite3DB) init(path: string) {
    s.raw = Sqlite3()
    s.raw.sqlite3_open(path as *const char, &s.handle)
}

func (s: Sqlite3DB) deinit() {
    s.raw.sqlite3_close(s.handle)
}

func (s: Sqlite3DB) exec(sql: string) -> ((), bool) {
    let rc = s.raw.sqlite3_exec(s.handle, sql as *const char, nil, nil, nil)
    return ((), rc != 0)
}
```

No `build` tag is needed on either file unless the *declared C
signatures* differ per platform — `vs.lib`'s targets already handle
which artifact gets linked. SQLite's ABI is identical everywhere, so
one untagged binding file covers all three OSes.

---

## 11. End-to-End Usage

All three artifact shapes in one manifest:

```
library     github.com/username/sqlite3
version     = "3.45.0"
description = "SQLite, native."

provider apt {
    package = "libsqlite3-dev"        // declared once (Rule 1)
    lib     = "libsqlite3.so.0"       // bare basename ⟹ basename match (Rule 3)

    target "amd64-linux" { hash = "h1:7f2e9a4c1b..." }
    target "arm64-linux" { hash = "h1:3d81ff09e2..." }

    target "amd64-linux" release "ubuntu-18.04" {   // finer key, not nesting (Rule 4)
        lib  = "libsqlite3.so0"
        hash = "h1:a912ef33c4..."
    }
}

provider fetch {                      // provider-level url ⟹ one shared archive (Rule 2)
    url    = "https://github.com/sqlite/sqlite-prebuilt/releases/download/v3.45.0/sqlite-allplatforms.zip"
    format = "zip"
    hash   = "h1:9f3a2b6c1d2e8a..."
    link   = "sqlite3"

    target "amd64-linux"   { lib = "linux-x64/lib/libsqlite3.so.0" }   // path ⟹ exact (Rule 3)
    target "arm64-linux"   { lib = "linux-arm64/lib/libsqlite3.so.0" }
    target "amd64-darwin"  { lib = "macos-x64/lib/libsqlite3.dylib" }
    target "amd64-windows" { lib = "windows-x64/bin/sqlite3.dll" }
}
```

Consumer:

```vertex
import "github.com/username/sqlite3"

func main() -> int {
    auto let db = sqlite3.Sqlite3DB(path: "app.db")

    let (_, failed) = db.exec(sql: "CREATE TABLE users (id INTEGER PRIMARY KEY)")
    if failed {
        // handle it
    }
    return 0
}
```

Access is package-qualified, as elsewhere in the grammar (`io.printf`,
`tcp.Client(...)`, `runtime.exit(0)`) — `sqlite3` here is the `package
sqlite3` from `db.vs`, not the import path. `auto let` (§32.1) handles
teardown: `deinit` fires at scope exit, closing the handle via the raw
binding, no `defer` needed.

| Layer | File | Job |
|---|---|---|
| Fetch + verify | `vs.lib` | Resolve a real artifact for the build target, hash-checked |
| Mount | `import "lib/sqlite3"` | Make the resolved artifact's symbols compilable against |
| Raw FFI | `raw.vs` | Declare the actual C function signatures |
| Idiomatic API | `db.vs` | Ordinary Vertex class, ordinary memory rules |
| Dependency graph | `vs.mod` (consumer) | One ordinary `require` line — nativeness invisible here by design |