namespace main

// Mirrors C's `struct sockaddr_in` at the extern boundary.
struct SockAddrIn {
  readonly sin_family: uint16
  readonly sin_port: uint16
  readonly sin_addr: uint32
  readonly sin_zero: FixedArray<byte, 8>

  constructor(family: uint16, port: uint16, addr: uint32) {
    this.sin_family = family
    this.sin_port = port
    this.sin_addr = addr
    this.sin_zero = FixedArray<byte, 8>()
  }
}

declare module "libc" {
  export func socket(domain: int32, type: int32, protocol: int32): int32
  export func setsockopt(
    sockfd: int32,
    level: int32,
    optname: int32,
    optval: mutable_ptr<int32>,
    optlen: uint32
  ): int32
  export func bind(sockfd: int32, addr: mutable_ptr<SockAddrIn>, addrlen: uint32): int32
  export func listen(sockfd: int32, backlog: int32): int32
  export func accept(
    sockfd: int32,
    addr: mutable_ptr<SockAddrIn> | null,
    addrlen: mutable_ptr<uint32> | null
  ): int32
  export func read(fd: int32, buf: mutable_ptr<byte>, count: usize): int64
  export func write(fd: int32, buf: mutable_ptr<byte>, count: usize): int64
  export func close(fd: int32): int32
  export func htons(hostshort: uint16): uint16
  export func htonl(hostlong: uint32): uint32
  export func puts(s: string): int32
}

const AF_INET: int32 = 2
const SOCK_STREAM: int32 = 1
const SOL_SOCKET: int32 = 1
const SO_REUSEADDR: int32 = 2
const INADDR_ANY: uint32 = 0
const PORT: uint16 = 8080
const BACKLOG: int32 = 16
const BUF_LEN: usize = 1024

// 2 + 2 + 4 + 8 with natural alignment and no tail padding. If the layout ever
// needs pinning, `@align(N)` on the struct is the spelling — not a literal here.
const SOCKADDR_IN_LEN: uint32 = uint32(sizeof<SockAddrIn>())

// Writes the full buffer, looping over short writes. false means the peer is
// gone or the descriptor errored.
func writeAll(fd: int32, base: mutable_ptr<byte>, total: int64): bool {
  var sent: int64 = int64(0)
  while sent < total {
    let n: int64 = write(fd, base.offset(int32(sent)), usize(total - sent))
    if n <= int64(0) {
      return false
    }
    sent = sent + n
  }
  return true
}

// Echoes until the peer closes. Buffer is inline in this frame — no allocation.
func handleClient(clientFd: int32): void {
  var buf: FixedArray<byte, 1024> = FixedArray<byte, 1024>()
  let base: mutable_ptr<byte> = addressof(buf[0])

  while true {
    let bytesRead: int64 = read(clientFd, base, BUF_LEN)
    if bytesRead <= int64(0) {
      return   // 0 = orderly shutdown, negative = read error
    }
    if !writeAll(clientFd, base, bytesRead) {
      return
    }
  }
}

func main(): int32 {
  let serverFd: int32 = socket(AF_INET, SOCK_STREAM, 0)
  if serverFd < 0 {
    puts("socket() failed")
    return 1
  }

  // Non-fatal: without it, rebinding after a restart fails while the old
  // listener sits in TIME_WAIT.
  var reuse: int32 = 1
  setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, addressof(reuse), uint32(sizeof<int32>()))

  var addr: SockAddrIn = SockAddrIn(uint16(AF_INET), htons(PORT), htonl(INADDR_ANY))

  if bind(serverFd, addressof(addr), SOCKADDR_IN_LEN) < 0 {
    puts("bind() failed")
    close(serverFd)
    return 1
  }

  if listen(serverFd, BACKLOG) < 0 {
    puts("listen() failed")
    close(serverFd)
    return 1
  }

  puts("listening on port 8080")

  // Single-threaded: one connection handled to completion before the next.
  while true {
    let clientFd: int32 = accept(serverFd, null, null)
    if clientFd < 0 {
      puts("accept() failed, continuing")
      continue
    }
    handleClient(clientFd)
    close(clientFd)
  }
}