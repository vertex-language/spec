package driver
import "linux/kernel"

// ── kernel bindings ──────────────────────────────────────────────────────────
class K : kernel {
    func printk(fmt: ...*const char) -> int32
    func register_chrdev(major: int32, name: *const char, fops: *const FileOps) -> int32
    func unregister_chrdev(major: int32, name: *const char)
    func copy_to_user(to: *char, from: *const char, n: int64) -> int64
}

// ── file_operations (abbreviated — must match full kernel struct layout) ──────
struct FileOps {
    owner:   *void?
    read:    func(*void, *char, int64, *int64) -> int64
    open:    func(*void, *void) -> int32
    release: func(*void, *void) -> int32
}

// ── globals ───────────────────────────────────────────────────────────────────
var k       = K()
var major:  int32       = 0
let message: *const char = "Hello from kernel!\n"
let msg_len: int64       = 19

// ── callbacks ─────────────────────────────────────────────────────────────────
func dev_open(inode: *void, file: *void) -> int32 {
    k.printk("[simple] open\n")
    return 0
}

func dev_release(inode: *void, file: *void) -> int32 {
    k.printk("[simple] release\n")
    return 0
}

func dev_read(file: *void, buf: *char, count: int64, offset: *int64) -> int64 {
    if count < msg_len {
        return 0
    }
    k.copy_to_user(buf, message, msg_len)
    return msg_len
}

// ── fops table ────────────────────────────────────────────────────────────────
let fops = FileOps{
    owner:   nil,
    read:    dev_read,
    open:    dev_open,
    release: dev_release,
}

// ── module entry / exit ───────────────────────────────────────────────────────
func init_module() -> int32 {
    major = k.register_chrdev(0, "simple", &fops)
    if major < 0 {
        k.printk("[simple] register_chrdev failed (%d)\n", major)
        return major
    }
    k.printk("[simple] loaded  major=%d\n", major)
    return 0
}

func cleanup_module() {
    k.unregister_chrdev(major, "simple")
    k.printk("[simple] unloaded\n")
}