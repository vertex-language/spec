package defer_test
build test

class C : c {
    func printf(fmt: ...*const char) -> int32
    func fopen(path: *const char, mode: *const char) -> *char?
    func fprintf(fp: *char, fmt: ...*const char) -> int32
    func fread(buf: *char, size: int32, count: int32, fp: *char) -> int32
    func fclose(fp: *char) -> int32
    func remove(path: *const char) -> int32
    func strncmp(a: *const char, b: *const char, n: int32) -> int32
}

class Handle {
    open: bool
    name: *const char
}

func (h: *Handle) init(name: *const char) {
    h.open = true
    h.name = name
}

// deinit appends the handle name to defer_log.txt so tests can
// verify that defer ran and in exactly what order
func (h: *Handle) deinit() {
    h.open = false
    var libc = C()
    if let fp = libc.fopen("defer_log.txt", "a") {
        libc.fprintf(fp, "%s\n", h.name)
        libc.fclose(fp)
    }
}

// ── standalone ────────────────────────────────────────────────────────────────
// these tests are self-contained and need no file I/O to pass

func test_defer_delete_no_crash() test {
    let h = Handle("h")
    defer h.delete()
}

func test_defer_does_not_block_return() test -> Expected(int32, "42") {
    let h = Handle("h")
    defer h.delete()
    return 42
}

func test_defer_with_early_return() test -> Expected(bool, "1") {
    let h = Handle("h")
    defer h.delete()
    if true {
        return true     // defer still fires at this scope exit
    }
    return false
}

func test_defer_multiple_no_crash() test {
    var a = Handle("a")
    var b = Handle("b")
    var c = Handle("c")
    defer a.delete()
    defer b.delete()
    defer c.delete()
}

func test_defer_anonymous_no_crash() test {
    var x: int32 = 0
    defer func(p: *int32) { p += 1 }(&x)
}

// ── file-verified pairs ───────────────────────────────────────────────────────
// each pair is two binaries that must run in order: _write then _read
// the _write test exercises defer and lets deinit append to defer_log.txt
// the _read test opens that file cold and checks exactly what was written

// pair 1 — single defer ran ───────────────────────────────────────────────────

func test_defer_single_write() test {
    var libc = C()
    libc.remove("defer_log.txt")
    let h = Handle("h")
    defer h.delete()            // deinit appends "h\n" on scope exit
}

func test_defer_single_read() test -> Expected(bool, "1") {
    var libc = C()
    var buf = [char](32)
    if let fp = libc.fopen("defer_log.txt", "r") {
        var n = libc.fread(&buf[0], 1, 31, fp)
        libc.fclose(fp)
        libc.remove("defer_log.txt")
        return n == 2 && libc.strncmp(&buf[0] as *const char, "h\n", 2) == 0
    }
    return false
}

// pair 2 — LIFO order ─────────────────────────────────────────────────────────

func test_defer_lifo_write() test {
    var libc = C()
    libc.remove("defer_log.txt")
    var a = Handle("a")
    var b = Handle("b")
    var c = Handle("c")
    defer a.delete()            // deferred first  → runs last  → "a\n" written last
    defer b.delete()
    defer c.delete()            // deferred last   → runs first → "c\n" written first
}

func test_defer_lifo_read() test -> Expected(bool, "1") {
    var libc = C()
    var buf = [char](32)
    if let fp = libc.fopen("defer_log.txt", "r") {
        var n = libc.fread(&buf[0], 1, 31, fp)
        libc.fclose(fp)
        libc.remove("defer_log.txt")
        return n == 6 && libc.strncmp(&buf[0] as *const char, "c\nb\na\n", 6) == 0
    }
    return false
}

// pair 3 — early return still fires defer ─────────────────────────────────────

func test_defer_early_return_write() test {
    var libc = C()
    libc.remove("defer_log.txt")
    let h = Handle("h")
    defer h.delete()
    if true {
        return              // defer must fire here, not fall through to end
    }
}

func test_defer_early_return_read() test -> Expected(bool, "1") {
    var libc = C()
    var buf = [char](32)
    if let fp = libc.fopen("defer_log.txt", "r") {
        var n = libc.fread(&buf[0], 1, 31, fp)
        libc.fclose(fp)
        libc.remove("defer_log.txt")
        return n == 2 && libc.strncmp(&buf[0] as *const char, "h\n", 2) == 0
    }
    return false
}