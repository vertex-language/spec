import "net/udp"

// --- client --- knows its target upfront
let client = udp.Client(host: "example.com", port: 9000)
defer client.delete()

client.send(data: req).try()

var buf = [uint8](repeating: 0, count: 1024)
let n = client.recv(into: &buf).try()

// --- server --- receives from anyone, replies explicitly
let server = udp.Server(host: "0.0.0.0", port: 9000)
defer server.delete()

var buf = [uint8](repeating: 0, count: 1024)

while true {
    let (n, from) = server.recv(into: &buf).try()
    server.send(to: from, data: buf.slice(0, n)).try()
}