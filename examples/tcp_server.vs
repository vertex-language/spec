namespace tcpserver

use native
use linux

// ---------------------------------------------------------------------------
// libc
//
// One resolver on linux — the library search path — so the specifier is bare
// and needs no scheme. `-lc`. Taken entirely on trust: the compiler never reads
// a header, and a signature that disagrees with the real symbol fails at link
// time.
// ---------------------------------------------------------------------------

declare struct sockaddr

declare module "c" {
  export func socket(domain: int32, kind: int32, protocol: int32): int32
  export func setsockopt(fd: int32, level: int32, opt: int32,
                         val: void_ptr, len: uint32): int32
  export func bind(fd: int32, addr: const_ptr<sockaddr>, len: uint32): int32
  export func listen(fd: int32, backlog: int32): int32
  export func accept(fd: int32,
                     addr: mutable_ptr<sockaddr> | null,
                     len: mutable_ptr<uint32> | null): int32
  export func read(fd: int32, buf: mutable_ptr<byte>, n: usize): int64
  export func write(fd: int32, buf: const_ptr<byte>, n: usize): int64
  export func close(fd: int32): int32
  export func htons(a: uint16): uint16
  export func __errno_location(): mutable_ptr<int32>
}

const AF_INET: int32 = 2
const SOCK_STREAM: int32 = 1
const SOL_SOCKET: int32 = 1
const SO_REUSEADDR: int32 = 2
const EINTR: int32 = 4

const BACKLOG: int32 = 128
const BUFSIZE: usize = 4096

func errno(): int32 {
  return __errno_location()[0]
}

// ---------------------------------------------------------------------------
// Boundary struct
//
// A real `struct` with fixed layout, not a `declare struct` — this one is
// written by us and passed by pointer, so its fields have to line up with the
// C definition. Natural alignment already gives 16 bytes; no @packed needed.
// ---------------------------------------------------------------------------

struct sockaddr_in {
  sin_family: uint16
  sin_port: uint16
  sin_addr: uint32
  sin_zero: array<byte, 8>

  constructor(port: uint16) {
    this.sin_family = uint16(AF_INET)
    this.sin_port = htons(port)
    this.sin_addr = 0            // INADDR_ANY — htonl would be a no-op on zero
    for i in 0..8 {
      this.sin_zero[i] = 0
    }
  }
}

// ---------------------------------------------------------------------------
// Socket
//
// A file descriptor with a deterministic destructor. This is the whole reason
// the error paths below are three lines instead of ten — every `return` past
// the constructor closes the fd on the way out, at a known point.
// ---------------------------------------------------------------------------

class Socket {
  readonly fd: int32

  constructor(fd: int32) {
    this.fd = fd
  }

  destructor() {
    close(this.fd)
  }
}

// ---------------------------------------------------------------------------
// Listener setup
//
// C has no exceptions to model, so failure is a sentinel return value, not a
// return union — there's nothing unwinding that a union would be describing.
// errno rides back alongside it in a tuple.
// ---------------------------------------------------------------------------

func listenOn(port: uint16): (Socket | null, int32) {
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  if fd < 0 {
    return (null, errno())
  }

  let s = Socket(fd)

  var one: int32 = 1
  if setsockopt(fd, SOL_SOCKET, SO_REUSEADDR,
                addressof(one) as void_ptr,
                uint32(sizeof<int32>())) < 0 {
    return (null, errno())
  }

  var addr = sockaddr_in(port)
  let sa = pointer_cast<sockaddr>(addressof(addr)) as const_ptr<sockaddr>

  if bind(fd, sa, uint32(sizeof<sockaddr_in>())) < 0 {
    return (null, errno())
  }

  if listen(fd, BACKLOG) < 0 {
    return (null, errno())
  }

  return (s, 0)
}

// ---------------------------------------------------------------------------
// Echo
// ---------------------------------------------------------------------------

func echo(c: readonly Socket): void {
  if let buf = try_alloc<byte>(BUFSIZE) {
    let data = buf.data()

    while true {
      let n = read(c.fd, data, BUFSIZE)
      if n <= 0 {
        return
      }

      var sent: int64 = 0
      while sent < n {
        let w = write(c.fd,
                      data.offset(usize(sent)) as const_ptr<byte>,
                      usize(n - sent))
        if w <= 0 {
          return
        }
        sent += w
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Accept loop
// ---------------------------------------------------------------------------

func serve(s: readonly Socket): void {
  while true {
    let cfd = accept(s.fd, null, null)

    if cfd < 0 {
      if errno() === EINTR {
        continue
      }
      return
    }

    let c = Socket(cfd)
    echo(c)
    // c's last reference dies here; destructor closes cfd
  }
}

func main(): int32 {
  let (server, err) = listenOn(uint16(8080))

  if let s = server {
    serve(s)
    return 0
  }

  return err
}