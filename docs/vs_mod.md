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
   through a system package manager (apt, brew, dnf, pacman, vcpkg, ...) or,
   for a small set of compiler-bundled libraries, a `builtin` recipe.

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
    linux   apt    libsqlite3-dev 3.45.0-1  link=sqlite3
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
matches the build target, fetching/vendoring that provider's artifact into
a common local folder, and linking it using the row's `link` name(s).

### 2.1 Row grammar

Each line inside a `pkg` block is one **provider entry**, in one of two
positional forms, plus an optional trailing named field:

**Short form** (3 positional fields) — uses the OS's default package
manager:

```
<os> <name> <version> [link=<libname>[,<libname>...]]
```

**Long form** (4 positional fields) — explicit manager, required when more
than one provider exists for the same OS, when the default manager isn't
wanted, or when using `builtin`:

```
<os> <manager> <name> <version> [link=<libname>[,<libname>...]]
```

The parser disambiguates short vs. long form by **positional** field count
alone (3 vs. 4) — `link=...` is a named field, not positional, and does not
affect that count. It may appear at the end of either form.

```
pkg sqlite3 (
    linux   libsqlite3-dev 3.45.0-1  link=sqlite3   # short form
    darwin  sqlite3        3.45.0                    # short form, link defaults to "sqlite3"
)

pkg openssl (
    linux apt    libssl-dev 3.0.2-0ubuntu1  link=ssl,crypto   # long form
    linux vcpkg  openssl    3.2.0           link=ssl,crypto   # long form
)
```

### 2.2 Columns / fields

| Field | Form | Required | Values | Notes |
|---|---|---|---|---|
| `os` | positional | yes | `linux`, `darwin`, `windows`, `any` | `any` is checked last, after all OS-specific rows fail to resolve |
| `manager` | positional | only in long form | `apt`, `dnf`, `pacman`, `brew`, `vcpkg`, `builtin`, ... | omitted in short form — the OS's default manager is used. `builtin` always requires long form. |
| `name` | positional | yes | string, no spaces | the package name *as that specific manager* names it — not necessarily the real link name. For `builtin`, this is the recipe's registered name (e.g. `cef`), not a package-manager-specific string. |
| `version` | positional | optional | string, no spaces | omitted = "whatever the manager currently has"; present = hard pin. For `builtin`, each recipe defines its own accepted version format and validates it before fetching. |
| `link` | named (`link=...`) | optional | comma-separated list of library names, no spaces | the actual name(s) passed to the linker (`-l<name>`). Defaults to the `pkg` block's logical name (the header, e.g. `sqlite3`) when omitted. Comma-separated for packages that produce multiple linkable libraries (e.g. openssl → `ssl`, `crypto`). |

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

`builtin` is never a default manager for any OS — it is never selected by
short form. It must always be written explicitly in long form.

### 2.4 `builtin` — compiler-bundled recipes

For a small set of popular C/C++ libraries with build pipelines too
involved to express as a normal `pkg` row pointed at a system package
manager (multi-stage cross-compilation, vendor-specific CDN artifacts,
unusual archive layouts, etc.), the compiler ships a hardcoded fetch/
extract/link recipe in Go, identified by `manager = builtin`:

```
pkg cef (
    linux   builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
    darwin  builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
    windows builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
)
```

**Rules:**

* `builtin` rows are always long form; `name` selects a recipe from an
  internal registry maintained in the compiler source, not an arbitrary
  string. If `name` has no matching registered recipe, this is a hard
  compile error — there is no silent fallback to another manager.
* A recipe owns its own fetch logic end to end (URL construction,
  download, checksum verification, archive extraction into the shared
  vendor folder, link-name resolution) the same way the apt/brew/vcpkg
  paths in §2.6 do, but without querying any external package database —
  the recipe itself *is* the resolution logic.
* Version pinning (§2.5) still applies: the version string is a hard
  requirement, validated against whatever format that specific recipe
  expects. A version the recipe doesn't recognize or can't fetch is a hard
  build error, never a silent substitution.
* The set of available `builtin` recipes is tied to the compiler version,
  not the project's `vs.mod`. Upgrading the compiler can add or remove
  `builtin` names; a `vs.mod` that resolved cleanly on one compiler version
  may need to switch a library to a normal `pkg`/manager-based row (or pin
  an older compiler) if a recipe is later removed.
* `builtin` should stay reserved for genuinely popular, broadly-shared
  libraries (CEF being the canonical example). It is not a general escape
  hatch for project-specific or rarely-used native dependencies — those
  belong in an imperative `build.vs` script instead, per the philosophy at
  the top of this document.

### 2.5 Resolution order

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

### 2.6 Version pinning

* A `version` field, when present, is a hard requirement. If the named
  manager cannot fulfill that exact version (the repo has moved on, no
  versions tap configured, etc.), this is a **hard build error**, never a
  silent substitution of a different version. For `builtin`, "cannot
  fulfill" means the recipe's own validation/fetch logic rejects or fails
  to locate that version.
* Omitting `version` is an explicit opt-out of pinning for that provider
  row — accepted as a deliberate tradeoff (e.g. for managers like Homebrew
  where pinning isn't reliably honorable without extra tooling), not a
  default to fall into casually. `builtin` recipes may choose to require a
  version always, since they have no "whatever the manager currently has"
  fallback to lean on.

### 2.7 Fetch/vendor/link behavior

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
* `builtin` → the registered Go recipe performs its own fetch (typically a
  direct download from a fixed, vendor-specific URL pattern), verifies the
  artifact, and extracts into the same project-local vendor folder. No
  package manager is consulted at all.

After vendoring, the artifact is linked using `link`'s value(s) — one
`-l<name>` per comma-separated entry — rather than any name derived from
the package's manager-specific naming. If `link` is omitted, the `pkg`
block's logical name is used as the sole link name. If the vendored
artifact contains no `.so`/`.a` matching the resolved link name(s), this is
a compile-time error raised at resolve time, not a deferred failure at the
final link step. This applies equally to `builtin`-sourced artifacts.

No `sudo`, no global state. Two checkouts of the same project resolve to
the same vendored artifacts given the same `vs.mod` and the same compiler
version.

---

## 3. Full example

```
// vs.mod

require github.com/someone/vertex-json v1.0.0

pkg sqlite3 (
    linux   apt    libsqlite3-dev 3.45.0-1  link=sqlite3
    darwin  brew   sqlite3        3.45.0
    windows vcpkg  sqlite3        3.45.0
)

pkg openssl (
    linux  apt   libssl-dev 3.0.2-0ubuntu1  link=ssl,crypto
    linux  vcpkg openssl    3.2.0           link=ssl,crypto
    darwin brew  openssl@3  3.2.0           link=ssl,crypto
)

pkg zlib (
    linux  apt  zlib1g-dev 1:1.3.dfsg-3.1  link=z
    darwin brew zlib
)

pkg cef (
    linux   builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
    darwin  builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
    windows builtin cef 120.1.10+g3ce4d96+chromium-120.0.6099.129  link=cef
)
```

Corresponding imports:

```vertex
import vjson   "github.com/someone/vertex-json"
import sqlite3 "pkg/lib/sqlite3"
import openssl "pkg/lib/openssl"
import zlib    "pkg/lib/zlib"
import cef     "pkg/lib/cef"
```

---

## 4. Grammar summary (informal)

```
file        := (require | pkg)*

require     := "require" modulePath version

pkg         := "pkg" identifier "(" providerRow+ ")"

providerRow := osTag identifier version? linkField?         // short form
             | osTag manager identifier version? linkField? // long form

linkField   := "link=" identifier ("," identifier)*

osTag       := "linux" | "darwin" | "windows" | "any"
manager     := "apt" | "dnf" | "pacman" | "brew" | "vcpkg" | "builtin" | identifier
version     := stringToken    // no ranges, no semver operators
modulePath  := stringToken    // import-path convention, §34
```

`builtin` is syntactically just another `manager` value — it requires no
grammar changes — but semantically it never participates in short-form
default resolution (§2.3) and its `name` values are resolved against a
fixed, compiler-internal registry rather than an external package
database (§2.4).

Formatting (column alignment, spacing) is not part of the grammar — `vs
fmt` is expected to canonicalize alignment the same way `gofmt` canonicalizes
`go.mod`, so hand-typed unaligned input is always acceptable as long as
tokens are whitespace-separated, `link=...` (when present) is the last
token on the line, and each row ends at a newline.