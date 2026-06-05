package main
import "linux/lib/c"

class C : c {
    func printf(fmt: ...*const char) -> int32
    func open(path: *const char, flags: int32, mode: int32) -> int32
    func write(fd: int32, buf: *const char, count: int32) -> int32
    func read(fd: int32, buf: *char, count: int32) -> int32
    func close(fd: int32) -> int32
    func exit(code: int32)
    func malloc(size: int32) -> *char
    func free(ptr: *char)
}


struct FS {
    handle: int32
}

func (fp: *FS) InitFS() -> *FS {

    var libc = C()

    // ── write ────────────────────────────────────────────────
    // O_WRONLY | O_CREAT | O_TRUNC = 1 | 64 | 512 = 577
    // mode 0644 = 420
    var wfd = libc.open("data.txt", 577, 420)
    if wfd < 0 {
        libc.printf("open(write) failed\n")
        libc.exit(1)
    }

    fp.handle = wfd

    return fp
}

func main() -> int {

    var fs = FS{}
    fs.InitFS()

    var libc = C()

    
    var i: int32 = 0
    while true {
        libc.write(fs.handle, "Hello, filesystem!\n", 19)
        if i >= 100 {
            break
        }
        i = i + 1
    }
    libc.close(fs.handle)
    libc.printf("wrote data.txt\n")

    // ── read back ────────────────────────────────────────────
    // O_RDONLY = 0
    var rfd = libc.open("data.txt", 0, 0)
    if rfd < 0 {
        libc.printf("open(read) failed\n")
        libc.exit(1)
    }

    var buf = libc.malloc(64)
    var n = libc.read(rfd, buf, 63)
    if n > 0 {
        // write raw bytes straight to stdout (fd 1) — no null-termination needed
        libc.write(1, reinterpret<*const char>(buf), n)
    }
    libc.free(buf)
    libc.close(rfd)

    return 0
}