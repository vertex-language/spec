package main
import "linux/lib/c"

class C : c {
    func printf(fmt: ...*const char) -> int32
    func socket(domain: int32, socktype: int32, protocol: int32) -> int32
    func setsockopt(sockfd: int32, level: int32, optname: int32, optval: *const char, optlen: int32) -> int32
    func bind(sockfd: int32, addr: *const char, addrlen: int32) -> int32
    func listen(sockfd: int32, backlog: int32) -> int32
    func accept(sockfd: int32, addr: *char, addrlen: *int32) -> int32
    func read(fd: int32, buf: *char, count: int32) -> int32
    func write(fd: int32, buf: *const char, count: int32) -> int32
    func close(fd: int32) -> int32
    func htons(port: int32) -> int32
    func exit(code: int32)

    func malloc(size: int32) -> *char
    func free(ptr: *char)
}

struct SockAddrIn {
    sin_family: int16
    sin_port:   int16
    sin_addr:   int32
    sin_zero:   int64
}

func main() -> int {
    var libc = C()

    // 1 ── create TCP socket  (AF_INET=2, SOCK_STREAM=1)
    var sfd = libc.socket(2, 1, 0)
    if sfd < 0 {
        libc.printf("socket() failed\n")
        libc.exit(1)
    }

    // 2 ── SO_REUSEADDR — allows restart without waiting out TIME_WAIT
    //      SOL_SOCKET=1, SO_REUSEADDR=2
    var opt: int32 = 1
    if libc.setsockopt(sfd, 1, 2, &opt as *const char, 4) < 0 {
        libc.printf("setsockopt() failed\n")
        libc.exit(1)
    }

    // 3 ── bind to 0.0.0.0:8080
    var addr = SockAddrIn{
        sin_family: int16(2),
        sin_port:   int16(libc.htons(8080)),
        sin_addr:   0,
        sin_zero:   int64(0),
    }
    if libc.bind(sfd, &addr as *const char, 16) < 0 {
        libc.printf("bind() failed\n")
        libc.exit(1)
    }

    // 4 ── listen
    if libc.listen(sfd, 8) < 0 {
        libc.printf("listen() failed\n")
        libc.exit(1)
    }
    libc.printf("TCP echo server listening on :8080\n")

    // 5 ── accept loop — single-threaded, one client at a time
    while true {
        var clen: int32 = 16
        var caddr = SockAddrIn{
            sin_family: int16(0),
            sin_port:   int16(0),
            sin_addr:   0,
            sin_zero:   int64(0),
        }
        var cfd = libc.accept(sfd, &caddr as *char, &clen)
        if cfd >= 0 {
            libc.printf("client connected  fd=%d\n", cfd)

            // 6 ── echo loop
            //var buf = [char](1024)

            //var buf_ptr = libc.malloc(1024)
        
            //while true {
                //var n = libc.read(cfd, buf_ptr, 1024)
                //var n = libc.read(cfd, &buf[0], 1024)
                //if n <= 0 {
                //    break
                //}
                //libc.write(cfd, &buf_ptr[0] as *const char, n)
                //libc.free(buf_ptr)

            //}    

            libc.close(cfd)
            libc.printf("client disconnected fd=%d\n", cfd)
        }
    }

    libc.close(sfd)
    return 0
}