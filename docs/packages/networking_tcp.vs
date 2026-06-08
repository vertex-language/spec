import "net/tcp"
import "fmt"

// client side
let client = tcp.Client(host: "example.com", port: 80)
defer client.delete()

client.write(data: req).try()

var buf = [uint8](repeating: 0, count: 4096)
let n = client.read(into: &buf).try()
fmt.Println(string(buf.slice(0, n)))


// server side
let server = tcp.Server(host: "0.0.0.0", port: 8080)
defer server.delete()

while true {
    let conn = server.accept().try()   // tcp.Conn — accepted connection

    func(conn: tcp.Conn) thread {
        defer conn.delete()
        // handle conn
    }(conn).spawn()
}