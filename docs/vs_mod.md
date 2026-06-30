# vs.mod

`vs.mod` is Vertex's dependency manifest. It plays the same role `go.mod`
plays for Go: a flat, hand-editable, diffable file declaring what a package
depends on. It is declarative only — no expressions, no control flow, no
arbitrary code execution. If a dependency's build needs more than this file
can express, that is a signal for an imperative build script (`build.vs`,
not covered here), not a reason to grow this grammar.

`vs.mod` covers two distinct kinds of dependency:

1. **Vertex packages** — ordinary `require` entries, identical in spirit to
   `go.mod`'s `require`.
2. **Native/system packages** — `pkg` blocks, for C libraries fetched
   through a system package manager (apt, brew, dnf, pacman, vcpkg, ...)
   rather than written in Vertex.

---

## 1. `require` — Vertex package dependencies

```
require github.com/someone/vertex-json v1.0.0
require github.com/someone/vertex-http v0.3.1
```

One dependency per line. No parentheses, no block — this mirrors `go.mod`'s
flat `require` form exactly. (`go.mod`'s parenthesized `require ( ... )`
group form may be added later for visual grouping; it carries identical
semantics to repeated single lines and is not load-bearing syntax.)

**Rules:**

* `require <module-path> <version>` — both fields mandatory.
* Module paths follow the same convention as import paths (§34).
* Versions are exact, pinned strings — no ranges, no `^`/`~` modifiers.
* `require` never branches on OS, architecture, or package manager. If a
  dependency needs that, it belongs in a `pkg` block instead, not `require`.

---

## 2. `pkg` — native/system package dependencies

```
pkg sqlite3 (
    linux   apt    libsqlite3-dev 3.45.0-1
    darwin  brew   sqlite3        3.45.0
    windows vcpkg  sqlite3        3.45.0
)
```

This corresponds to an import written as:

```vertex
import sqlite3 "pkg/lib/sqlite3"
```

The logical name (`sqlite3`) in the `pkg` block header must match the final
path segment of the `pkg/lib/<name>` import. The compiler resolves the
import by finding the matching `pkg` block, picking the row whose `os`
matches the build target, and fetching/vendoring that provider's artifact
into a common local folder for linking.

### 2.1 Row grammar

Each line inside a `pkg` block is one **provider entry**, in one of two
forms:

**Short form** (3 fields) — uses the OS's default package manager:

```
<os> <name> <version>
```

**Long form** (4 fields) — explicit manager, required when more than one
provider exists for the same OS, or when the default manager isn't wanted:

```
<os> <manager> <name> <version>
```

The parser disambiguates by field count alone — no keyword needed. Three
space-separated tokens after the OS column means short form; four means
long form.

```
pkg sqlite3 (
    linux   libsqlite3-dev 3.45.0-1     # short form: linux default = apt
    darwin  sqlite3        3.45.0       # short form: darwin default = brew
)

pkg openssl (
    linux apt    libssl-dev 3.0.2-0ubuntu1   # long form: two linux providers,
    linux vcpkg  openssl    3.2.0             #   so manager must be explicit
)
```

### 2.2 Columns

| Column | Required | Values | Notes |
|---|---|---|---|
| `os` | yes | `linux`, `darwin`, `windows`, `any` | `any` is checked last, after all OS-specific rows fail to resolve |
| `manager` | only in long form | `apt`, `dnf`, `pacman`, `brew`, `vcpkg`, ... | omitted in short form — the OS's default manager is used |
| `name` | yes | string, no spaces | the package name *as that specific manager* names it |
| `version` | optional | string, no spaces | omitted = "whatever the manager currently has"; present = hard pin |

### 2.3 Default managers per OS (short form)

| `os` | default `manager` |
|---|---|
| `linux` | `apt` |
| `darwin` | `brew` |
| `windows` | `vcpkg` |

This table is baked into the compiler. Short form on `linux` always resolves
to `apt` — it does **not** mean "whatever manager is detected on the host."
Users on Fedora/Arch/Alpine must use long form (`linux dnf ...`,
`linux pacman ...`, etc.) explicitly; there is no auto-detection fallback,
because silent manager substitution is exactly the unpredictable-build
failure mode this format exists to avoid.

### 2.4 Resolution order

Given a build target's OS:

1. Collect every row in the `pkg` block whose `os` matches the target
   exactly (`linux`, `darwin`, or `windows`).
2. If more than one such row exists (multiple managers declared for that
   OS), the **first matching row in file order** is used. There is no
   "best available" heuristic — order in the file is the tie-break, and it
   is deterministic and visible by reading the file top to bottom.
3. If no OS-specific row matches, fall back to a row with `os = any`, if
   present.
4. If nothing matches, this is a hard compile error — there is no silent
   "skip the dependency" behavior.

### 2.5 Version pinning

* A `version` field, when present, is a hard requirement. If the named
  manager cannot fulfill that exact version (the repo has moved on, no
  versions tap configured, etc.), this is a **hard build error**, never a
  silent substitution of a different version.
* Omitting `version` is an explicit opt-out of pinning for that provider
  row — accepted as a deliberate tradeoff (e.g. for managers like Homebrew
  where pinning isn't reliably honorable without extra tooling), not a
  default to fall into casually.

### 2.6 Fetch/vendor behavior

Resolution never mutates the host system (no `apt install`, no `brew
install`). The compiler driver downloads the package manager's artifact
directly:

* apt/dnf/pacman → fetch the `.deb`/`.rpm`/package archive without
  installing, extract (`dpkg -x`-equivalent) into a project-local vendor
  folder.
* brew → fetch the bottle without `brew install`, extract into the vendor
  folder.
* vcpkg → resolve via vcpkg's own manifest/build, output placed in the
  vendor folder. (Note: vcpkg builds from source by default for many ports,
  which is materially slower than a binary-artifact fetch — prefer a
  native-manager provider row when one exists and reserve vcpkg for
  cross-platform coverage gaps, e.g. Windows, or libraries with no native
  packaging.)

No `sudo`, no global state. Two checkouts of the same project resolve to
the same vendored artifacts given the same `vs.mod`.

---

## 3. Full example

```
// vs.mod

require github.com/someone/vertex-json v1.0.0

pkg sqlite3 (
    linux   apt    libsqlite3-dev 3.45.0-1
    darwin  brew   sqlite3        3.45.0
    windows vcpkg  sqlite3        3.45.0
)

pkg openssl (
    linux apt    libssl-dev 3.0.2-0ubuntu1
    linux vcpkg  openssl    3.2.0
    darwin brew  openssl@3  3.2.0
)

pkg zlib (
    linux  zlib1g-dev 1:1.3.dfsg-3.1
    darwin zlib
)
```

Corresponding imports:

```vertex
import vjson "github.com/someone/vertex-json"
import sqlite3 "pkg/lib/sqlite3"
import openssl "pkg/lib/openssl"
import zlib    "pkg/lib/zlib"
```

---

## 4. Grammar summary (informal)

```
file        := (require | pkg)*

require     := "require" modulePath version

pkg         := "pkg" identifier "(" providerRow+ ")"

providerRow := osTag identifier version?              // short form
             | osTag manager identifier version?      // long form

osTag       := "linux" | "darwin" | "windows" | "any"
manager     := "apt" | "dnf" | "pacman" | "brew" | "vcpkg" | identifier
version     := stringToken    // no ranges, no semver operators
modulePath  := stringToken    // import-path convention, §34
```

Formatting (column alignment, spacing) is not part of the grammar — `vs
fmt` is expected to canonicalize alignment the same way `gofmt` canonicalizes
`go.mod`, so hand-typed unaligned input is always acceptable as long as
tokens are whitespace-separated and each row ends at a newline.