## `net/udp`

UDP is connectionless — there is no `Accept()` loop. You bind a socket and exchange datagrams directly. `Read` returns sender address alongside the bytes so you know where to reply.

```vertex
import "net/udp"

// ── Core Types ────────────────────────────────────────────────────────────────
struct Datagram {
    Data: [uint8]      // heap-allocated, caller owns
    From: string       // sender address "ip:port"
}

enum Error {
    case None, AddressInUse, AddressNotAvailable, NetworkUnreachable,
         PermissionDenied, Timeout, InvalidAddress, Closed
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Socket(port: uint16) -> (Socket, Error)                          // bind — server role
func Peer(address: string, port: uint16) -> (Peer, Error)             // targeted sender — client role

// ── Socket Methods ────────────────────────────────────────────────────────────
func (s: Socket) Read(dest: *uint8, len: uint32) -> (Datagram, Error)                            // zero-alloc path
func (s: Socket) ReadDatagram() -> (Datagram, Error)                                             // heap path — caller must delete Datagram.Data
func (s: Socket) WriteTo(dest: string, port: uint16, src: *const uint8, len: uint32) -> (uint32, Error)
func (s: Socket) SetTimeout(ms: uint32) -> ((), Error)
func (s: Socket) Close() -> ((), Error)

// ── Peer Methods ──────────────────────────────────────────────────────────────
func (p: Peer) Write(src: *const uint8, len: uint32) -> (uint32, Error)
func (p: Peer) WriteString(data: string) -> (uint32, Error)
func (p: Peer) Close() -> ((), Error)

```

**Example — DNS-style request/reply:**

```vertex
func queryDNS() -> ((), udp.Error) {
    let sock = udp.Socket(port: 0)?
    defer sock.delete()

    var packet: [uint8; 512]
    // ... build DNS query into packet ...

    let _ = sock.WriteTo(
        dest: "8.8.8.8",
        port: 53,
        src:  &packet as *const uint8,
        len:  512
    )?

    var reply: [uint8; 512]
    let dg = sock.Read(dest: &reply as *uint8, len: 512)?
    // dg.From holds the sender address

    return ((), .None)
}

```

The zero-alloc `Read` path takes a pre-allocated stack buffer — no heap, no `.delete()` on the data. The `ReadDatagram` convenience path heap-allocates `Datagram.Data` and the caller must delete it.

---

## `net/icmp`

ICMP sits below TCP and UDP entirely. The constructor requires elevated OS permissions on most platforms — the `Error` enum reflects that explicitly.

```vertex
import "net/icmp"

// ── Core Types ────────────────────────────────────────────────────────────────
enum MessageType {
    case EchoRequest, EchoReply, Unreachable, TimeExceeded
}

struct Message {
    Type:     icmp.MessageType
    Code:     uint8
    Checksum: uint16
    Data:     [uint8]    // heap-allocated, caller owns
}

enum Error {
    case None, PermissionDenied, Timeout, NetworkUnreachable, MalformedPacket
}

// ── Constructor ───────────────────────────────────────────────────────────────
func Socket() -> (Socket, Error)    // requires elevated permissions

// ── Socket Methods ────────────────────────────────────────────────────────────
func (s: Socket) SendEcho(address: string, id: uint16, seq: uint16, payload: *const uint8, len: uint32) -> ((), Error)
func (s: Socket) Receive(dest: *uint8, len: uint32) -> (Message, Error)    // zero-alloc header path
func (s: Socket) SetTimeout(ms: uint32) -> ((), Error)
func (s: Socket) Close() -> ((), Error)

```

**Example — manual ping:**

```vertex
func ping(host: string) -> ((), icmp.Error) {
    let sock = icmp.Socket()?    // fails here on PermissionDenied
    defer sock.delete()

    sock.SetTimeout(ms: 1000)?

    var payload: [uint8; 32]
    payload.fill(0xAB)

    sock.SendEcho(
        address: host,
        id:      1,
        seq:     1,
        payload: &payload as *const uint8,
        len:     32
    )?

    var buf: [uint8; 64]
    let msg = sock.Receive(dest: &buf as *uint8, len: 64)?

    if msg.Type == .EchoReply {
        // round trip confirmed
    }

    return ((), .None)
}

```

ICMP has no stream — it is fire and receive. There is no `Accept()` loop, no connection state. The socket is purely a raw packet I/O handle.

---

## `net/https`

HTTPS is `net/http` with a TLS layer underneath. The constructor takes a `TLSConfig` struct; TLS concerns live there and nowhere else.

```vertex
import "net/https"

// ── TLS Configuration ─────────────────────────────────────────────────────────
struct TLSConfig {
    CertFile:           string    // path to PEM certificate
    KeyFile:            string    // path to PEM private key
    CAFile:             string    // optional — mutual TLS
    InsecureSkipVerify: bool      // dev only — compile-time warning emitted
    MinVersion:         uint16    // 0x0303 = TLS 1.2, 0x0304 = TLS 1.3
}

enum Error {
    case None, HandshakeFailed, CertExpired, CertUntrusted,
         HostnameMismatch, ProtocolVersion, ConnectionRefused
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Client(cfg: TLSConfig) -> (Client, Error)
func Server(port: uint16, cfg: TLSConfig) -> (Server, Error)

// ── Client Methods ────────────────────────────────────────────────────────────
func (c: Client) Get(url: string) -> (Response, Error)
func (c: Client) Post(url: string, contentType: string, body: [uint8]) -> (Response, Error)
func (c: Client) Send(req: Request) -> (Response, Error)
func (c: Client) Close() -> ((), Error)

// ── Server Methods ────────────────────────────────────────────────────────────
func (s: Server) Accept() -> (Context, Error)
func (s: Server) Close() -> ((), Error)

```

`Response`, `Request`, and `Context` are re-exported from `net/http` — there is no duplication. The only thing `net/https` owns is the TLS handshake layer and `TLSConfig`.

**Example:**

```vertex
func secureGet() -> ((), https.Error) {
    let cfg = https.TLSConfig{
        CertFile:           "",
        KeyFile:            "",
        CAFile:             "",
        InsecureSkipVerify: false,
        MinVersion:         0x0304,    // TLS 1.3 minimum
    }

    let client = https.Client(cfg: cfg)?
    defer client.delete()

    let resp = client.Get(url: "https://api.example.com/data")?
    defer resp.Body.delete()
    defer resp.Headers.delete()

    return ((), .None)
}

```

The developer's muscle memory is identical to `net/http`. The only new concept is threading `TLSConfig` through the constructor.

---

## `net/bluetooth`

Bluetooth has two completely separate stacks — Classic (BR/EDR, for audio and serial) and Low Energy (BLE, for sensors and IoT). They share a constructor model but diverge at the API level.

```vertex
import "net/bluetooth"

// ── Core Types ────────────────────────────────────────────────────────────────
struct Device {
    Address: string    // "AA:BB:CC:DD:EE:FF"
    Name:    string
    RSSI:    int8      // signal strength
}

struct UUID {
    Value: string      // "0000180d-0000-1000-8000-00805f9b34fb"
}

enum Transport {
    case Classic, BLE
}

enum Error {
    case None, AdapterUnavailable, ScanTimeout, ConnectionFailed,
         PairingFailed, ServiceNotFound, CharacteristicNotFound,
         PermissionDenied
}

// ── Adapter — the hardware radio ──────────────────────────────────────────────
func Adapter() -> (Adapter, Error)

func (a: Adapter) Scan(transport: Transport, durationMs: uint32) -> ([Device], Error)    // heap, caller owns
func (a: Adapter) StopScan() -> ((), Error)
func (a: Adapter) Close() -> ((), Error)

```

**Classic (BR/EDR) — serial-style stream:**

```vertex
// ── Classic Constructor ───────────────────────────────────────────────────────
func ClassicConn(adapter: Adapter, address: string) -> (ClassicConn, Error)

// ── ClassicConn Methods ───────────────────────────────────────────────────────
func (c: ClassicConn) Read(dest: *uint8, len: uint32) -> (uint32, Error)
func (c: ClassicConn) Write(src: *const uint8, len: uint32) -> (uint32, Error)
func (c: ClassicConn) WriteString(data: string) -> (uint32, Error)
func (c: ClassicConn) Close() -> ((), Error)

```

Classic Bluetooth is effectively a wireless serial port — the API is intentionally nearly identical to `net/tcp`'s `Conn`.

**BLE — characteristic-based I/O:**

```vertex
// ── BLE Constructor ───────────────────────────────────────────────────────────
func BLEConn(adapter: Adapter, address: string) -> (BLEConn, Error)

// ── BLE Service / Characteristic Discovery ───────────────────────────────────
func (c: BLEConn) DiscoverServices() -> ([UUID], Error)                        // heap, caller owns
func (c: BLEConn) DiscoverCharacteristics(service: UUID) -> ([UUID], Error)    // heap, caller owns

// ── BLE Read / Write / Notify ─────────────────────────────────────────────────
func (c: BLEConn) ReadCharacteristic(char: UUID, dest: *uint8, len: uint32) -> (uint32, Error)
func (c: BLEConn) WriteCharacteristic(char: UUID, src: *const uint8, len: uint32) -> ((), Error)

// Subscribe wires a channel — the radio pushes into it on every hardware notification
func (c: BLEConn) Subscribe(char: UUID, ch: chan [uint8]) -> ((), Error)
func (c: BLEConn) Unsubscribe(char: UUID) -> ((), Error)

func (c: BLEConn) Close() -> ((), Error)

```

**Example — BLE heart rate monitor:**

```vertex
func readHeartRate() -> ((), bluetooth.Error) {
    let adapter = bluetooth.Adapter()?
    defer adapter.delete()

    let devices = adapter.Scan(transport: .BLE, durationMs: 3000)?
    defer devices.delete()

    let hrm = bluetooth.BLEConn(adapter: adapter, address: devices[0].Address)?
    defer hrm.delete()

    let heartRateUUID = bluetooth.UUID{Value: "00002a37-0000-1000-8000-00805f9b34fb"}

    // wire hardware notifications directly to a buffered channel
    let readings: chan [uint8] = {cap: 16}
    hrm.Subscribe(char: heartRateUUID, ch: readings)?

    // consume on a virtual thread — suspends at zero CPU between beats
    async func(ch: chan [uint8]) {
        while true {
            let data = ch.receive()
            let bpm = data[1]    // HRM profile byte layout
            // process bpm
        }
    }(readings)

    return ((), .None)
}

```

`Subscribe` hands you a `chan [uint8]` that the radio driver pushes into. BLE notifications slot directly into Vertex's `select` and `async` concurrency model with zero special casing.

---

## `net/serial`

Serial is a byte stream with a baud rate. The API is nearly identical to `net/tcp`'s `Conn` intentionally — at the data layer, that is exactly what it is.

```vertex
import "net/serial"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Parity {
    case None, Odd, Even
}

enum StopBits {
    case One, Two
}

struct Config {
    BaudRate: uint32       // 9600, 115200, etc.
    DataBits: uint8        // 5, 6, 7, 8
    Parity:   serial.Parity
    StopBits: serial.StopBits
    Timeout:  uint32       // read timeout in ms, 0 = block forever
}

enum Error {
    case None, PortNotFound, PermissionDenied, Timeout,
         FramingError, ParityError, Overrun, NotOpen
}

// ── Constructor ───────────────────────────────────────────────────────────────
// path is platform-specific: "/dev/ttyUSB0", "COM3", etc.
func Port(path: string, cfg: serial.Config) -> (Port, Error)

// ── Port Methods ──────────────────────────────────────────────────────────────
func (p: Port) Read(dest: *uint8, len: uint32) -> (uint32, Error)
func (p: Port) Write(src: *const uint8, len: uint32) -> (uint32, Error)
func (p: Port) WriteString(data: string) -> (uint32, Error)
func (p: Port) ReadLine(dest: *uint8, maxLen: uint32) -> (uint32, Error)    // reads until '\n'
func (p: Port) Flush() -> ((), Error)      // drain TX buffer
func (p: Port) Purge() -> ((), Error)      // discard RX buffer
func (p: Port) SetTimeout(ms: uint32) -> ((), Error)
func (p: Port) Close() -> ((), Error)

```

**Example — talk to an Arduino:**

```vertex
func readSensor() -> ((), serial.Error) {
    let cfg = serial.Config{
        BaudRate: 115200,
        DataBits: 8,
        Parity:   .None,
        StopBits: .One,
        Timeout:  1000,
    }

    let port = serial.Port(path: "/dev/ttyUSB0", cfg: cfg)?
    defer port.delete()

    let _ = port.WriteString(data: "READ_TEMP\n")?

    var buf: [uint8; 64]
    let n = port.Read(dest: &buf as *uint8, len: 64)?

    return ((), .None)
}

```

`ReadLine` is the one convenience addition — nearly every UART protocol is newline-delimited and manually scanning for `\n` in every project is pointless boilerplate.

---

## `net/usb`

USB requires navigating the device descriptor tree — device → configuration → interface → endpoint — before any data can be exchanged. The API models that hierarchy explicitly.

```vertex
import "net/usb"

// ── Descriptor Types ──────────────────────────────────────────────────────────
struct DeviceInfo {
    VendorID:     uint16
    ProductID:    uint16
    Manufacturer: string
    Product:      string
    Serial:       string
    BusNumber:    uint8
    Address:      uint8
}

enum TransferType {
    case Bulk, Interrupt, Isochronous, Control
}

enum Direction {
    case In, Out
}

struct EndpointInfo {
    Address:      uint8
    TransferType: usb.TransferType
    MaxPacket:    uint16
    Direction:    usb.Direction
}

enum Error {
    case None, DeviceNotFound, AccessDenied, TransferFailed,
         Timeout, Disconnected, InvalidDescriptor,
         EndpointStall, Overflow
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Enumerate() -> ([DeviceInfo], Error)                               // heap, caller owns
func Open(vendorID: uint16, productID: uint16) -> (Device, Error)       // open by VID/PID
func OpenAt(bus: uint8, address: uint8) -> (Device, Error)              // open by bus address

// ── Device Methods ────────────────────────────────────────────────────────────
func (d: Device) ClaimInterface(index: uint8) -> (Interface, Error)
func (d: Device) Reset() -> ((), Error)
func (d: Device) Close() -> ((), Error)

// ── Interface Methods ─────────────────────────────────────────────────────────
func (i: Interface) Endpoints() -> ([EndpointInfo], Error)    // heap, caller owns
func (i: Interface) Release() -> ((), Error)

// ── Transfer Methods ──────────────────────────────────────────────────────────
// Bulk — high throughput, no timing guarantee (storage, serial adapters)
func (i: Interface) BulkRead(endpoint: uint8, dest: *uint8, len: uint32, timeoutMs: uint32) -> (uint32, Error)
func (i: Interface) BulkWrite(endpoint: uint8, src: *const uint8, len: uint32, timeoutMs: uint32) -> (uint32, Error)

// Interrupt — low latency, small packets (HID: keyboards, mice, gamepads)
func (i: Interface) InterruptRead(endpoint: uint8, dest: *uint8, len: uint32, timeoutMs: uint32) -> (uint32, Error)
func (i: Interface) InterruptWrite(endpoint: uint8, src: *const uint8, len: uint32, timeoutMs: uint32) -> (uint32, Error)

// Control — device configuration and vendor commands
func (i: Interface) ControlTransfer(
    requestType: uint8,
    request:     uint8,
    value:       uint16,
    index:       uint16,
    data:        *uint8,
    len:         uint16,
    timeoutMs:   uint32
) -> (uint32, Error)

```

**Example — read from a USB HID gamepad:**

```vertex
func readGamepad() -> ((), usb.Error) {
    // Sony DualShock 4: VID 0x054C, PID 0x05C4
    let device = usb.Open(vendorID: 0x054C, productID: 0x05C4)?
    defer device.delete()

    let iface = device.ClaimInterface(index: 0)?
    defer iface.Release()

    var report: [uint8; 64]

    while true {
        // endpoint 0x81 = IN endpoint 1 (direction baked into address)
        let n = iface.InterruptRead(
            endpoint:  0x81,
            dest:      &report as *uint8,
            len:       64,
            timeoutMs: 5000
        )?

        let leftX = report[1]
        let leftY = report[2]
    }

    return ((), .None)
}

```

**Example — enumerate all connected devices:**

```vertex
func listDevices() -> ((), usb.Error) {
    let devices = usb.Enumerate()?
    defer devices.delete()

    for d in devices {
        // access d.VendorID, d.ProductID, d.Product, etc.
    }

    return ((), .None)
}

```

---

## `net/can`

CAN bus has no concept of connections or streams. Every node broadcasts frames into shared space; every other node decides whether to process them based on the arbitration ID. There is no `Dial`, no `Accept` — just a bus handle you read and write frames to.

```vertex
import "net/can"

// ── Core Types ────────────────────────────────────────────────────────────────
struct Frame {
    ID:       uint32        // 11-bit standard or 29-bit extended arbitration ID
    Extended: bool          // true = 29-bit extended ID
    RTR:      bool          // remote transmission request
    Data:     [uint8; 8]    // CAN frames are max 8 bytes — fixed stack array
    Len:      uint8         // actual payload length 0–8
}

// CAN FD extends payload to 64 bytes
struct FDFrame {
    ID:       uint32
    Extended: bool
    BRS:      bool          // bit rate switch
    ESI:      bool          // error state indicator
    Data:     [uint8; 64]
    Len:      uint8
}

struct Filter {
    ID:   uint32
    Mask: uint32            // 1 bits = must match, 0 bits = don't care
}

enum Error {
    case None, InterfaceNotFound, BusOff, ErrorPassive,
         Overrun, Timeout, PermissionDenied, NotSupported
}

// ── Constructor ───────────────────────────────────────────────────────────────
// iface is the OS interface name: "can0", "vcan0", "can1"
func Bus(iface: string) -> (Bus, Error)

// ── Bus Methods ───────────────────────────────────────────────────────────────
func (b: Bus) Read(frame: *can.Frame) -> ((), Error)              // zero-alloc — writes into caller's frame
func (b: Bus) Write(frame: *const can.Frame) -> ((), Error)
func (b: Bus) ReadFD(frame: *can.FDFrame) -> ((), Error)
func (b: Bus) WriteFD(frame: *const can.FDFrame) -> ((), Error)

// hardware-level filter — only matching frames reach Read()
func (b: Bus) SetFilters(filters: *const can.Filter, count: uint32) -> ((), Error)
func (b: Bus) ClearFilters() -> ((), Error)

func (b: Bus) SetTimeout(ms: uint32) -> ((), Error)
func (b: Bus) ErrorCounts(txErrors: *uint32, rxErrors: *uint32) -> ((), Error)
func (b: Bus) Close() -> ((), Error)

```

`Frame.Data` is a fixed stack array `[uint8; 8]` — CAN frames are bounded by protocol at 8 bytes, so a heap allocation here would be wasteful. The type system enforces the hardware constraint directly.

**Example — automotive OBD-II RPM query:**

```vertex
func readRPM() -> ((), can.Error) {
    let bus = can.Bus(iface: "can0")?
    defer bus.delete()

    // only receive frames with ID 0x7E8 (OBD-II ECU response)
    var filter = can.Filter{ID: 0x7E8, Mask: 0x7FF}
    bus.SetFilters(filters: &filter as *const can.Filter, count: 1)?

    // send OBD-II Mode 01 PID 0x0C (engine RPM)
    var req = can.Frame{
        ID:       0x7DF,
        Extended: false,
        RTR:      false,
        Data:     [0x02, 0x01, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00],
        Len:      8,
    }
    bus.Write(frame: &req)?

    // read the ECU response — zero heap, frame lives on the stack
    var resp = can.Frame{
        ID:       0,
        Extended: false,
        RTR:      false,
        Data:     [0, 0, 0, 0, 0, 0, 0, 0],
        Len:      0,
    }
    bus.Read(frame: &resp)?

    // OBD-II RPM formula: ((A * 256) + B) / 4
    let rpm = (uint32(resp.Data[3]) * 256 + uint32(resp.Data[4])) / 4

    return ((), .None)
}

```

---

## `hw/gpio`

GPIO is the most fundamental hardware interface. The complexity is almost entirely in configuration — which pin, which direction, which pull resistor, which edge triggers the interrupt.

```vertex
import "hw/gpio"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Direction {
    case Input, Output
}

enum Pull {
    case None, Up, Down
}

enum Edge {
    case Rising, Falling, Both
}

enum Error {
    case None, PinNotFound, PermissionDenied, AlreadyClaimed,
         InvalidOperation, ChipNotFound
}

// ── Constructor ───────────────────────────────────────────────────────────────
// chip is platform-specific: "/dev/gpiochip0" on Linux, "GPIO" on bare metal
func Pin(chip: string, number: uint32, dir: gpio.Direction, pull: gpio.Pull) -> (Pin, Error)

// ── Pin Methods ───────────────────────────────────────────────────────────────
func (p: Pin) High() -> ((), Error)
func (p: Pin) Low() -> ((), Error)
func (p: Pin) Toggle() -> ((), Error)
func (p: Pin) Set(value: bool) -> ((), Error)      // true = high
func (p: Pin) Read() -> (bool, Error)              // true = high

// OnEdge pushes into the channel on every hardware interrupt
func (p: Pin) OnEdge(edge: gpio.Edge, ch: chan bool) -> ((), Error)
func (p: Pin) ClearEdge() -> ((), Error)

func (p: Pin) SetDirection(dir: gpio.Direction) -> ((), Error)
func (p: Pin) Close() -> ((), Error)

```

**Example — blink an LED, stop on button press:**

```vertex
func blinkAndWait() -> ((), gpio.Error) {
    let led = gpio.Pin(
        chip:   "/dev/gpiochip0",
        number: 17,
        dir:    .Output,
        pull:   .None
    )?
    defer led.delete()

    let button = gpio.Pin(
        chip:   "/dev/gpiochip0",
        number: 27,
        dir:    .Input,
        pull:   .Up
    )?
    defer button.delete()

    let presses: chan bool = {cap: 4}
    button.OnEdge(edge: .Rising, ch: presses)?

    var running = true
    while running {
        led.Toggle()?

        if let _ = presses.tryReceive() {
            running = false
        }

        time.SleepMs(500)
    }

    led.Low()?
    return ((), .None)
}

```

---

## `hw/i2c` and `hw/spi`

### `hw/i2c`

```vertex
import "hw/i2c"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Speed {
    case Standard    // 100 kHz
    case Fast        // 400 kHz
    case FastPlus    // 1 MHz
    case HighSpeed   // 3.4 MHz
}

enum Error {
    case None, BusNotFound, AddressNACK, BusArbitrationLost,
         Timeout, PermissionDenied, BusBusy
}

// ── Constructor ───────────────────────────────────────────────────────────────
// path is the OS bus path: "/dev/i2c-1" on Linux
func Bus(path: string, speed: i2c.Speed) -> (Bus, Error)

// ── Bus Methods ───────────────────────────────────────────────────────────────
// Raw transfers — zero-alloc, caller owns buffers
func (b: Bus) Write(address: uint8, src: *const uint8, len: uint32) -> ((), Error)
func (b: Bus) Read(address: uint8, dest: *uint8, len: uint32) -> ((), Error)

// Register read/write — the pattern used by virtually every I2C sensor
func (b: Bus) WriteReg(address: uint8, reg: uint8, value: uint8) -> ((), Error)
func (b: Bus) ReadReg(address: uint8, reg: uint8, dest: *uint8, len: uint32) -> ((), Error)
func (b: Bus) ReadRegByte(address: uint8, reg: uint8) -> (uint8, Error)
func (b: Bus) ReadRegWord(address: uint8, reg: uint8) -> (uint16, Error)

// Scan detects which addresses respond — useful during hardware bring-up
func (b: Bus) Scan() -> ([uint8], Error)    // heap, caller owns

func (b: Bus) Close() -> ((), Error)

```

**Example — read from an MPU-6050 accelerometer/gyroscope:**

```vertex
func readIMU() -> ((), i2c.Error) {
    let bus = i2c.Bus(path: "/dev/i2c-1", speed: .Fast)?
    defer bus.delete()

    let MPU6050: uint8 = 0x68

    // wake the device — write 0x00 to power management register 0x6B
    bus.WriteReg(address: MPU6050, reg: 0x6B, value: 0x00)?

    // read 6 bytes of accelerometer data starting at register 0x3B
    var raw: [uint8; 6]
    bus.ReadReg(address: MPU6050, reg: 0x3B, dest: &raw as *uint8, len: 6)?

    // combine high and low bytes
    let axRaw = int16(raw[0]) << 8 | int16(raw[1])
    let ayRaw = int16(raw[2]) << 8 | int16(raw[3])
    let azRaw = int16(raw[4]) << 8 | int16(raw[5])

    return ((), .None)
}

```

---

### `hw/spi`

```vertex
import "hw/spi"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Mode {
    case Mode0    // CPOL=0 CPHA=0
    case Mode1    // CPOL=0 CPHA=1
    case Mode2    // CPOL=1 CPHA=0
    case Mode3    // CPOL=1 CPHA=1
}

enum BitOrder {
    case MSBFirst, LSBFirst
}

struct Config {
    SpeedHz:     uint32
    Mode:        spi.Mode
    BitOrder:    spi.BitOrder
    BitsPerWord: uint8        // almost always 8
}

enum Error {
    case None, DeviceNotFound, TransferFailed, PermissionDenied,
         InvalidConfig, Timeout
}

// ── Constructor ───────────────────────────────────────────────────────────────
// path is the OS device path: "/dev/spidev0.0" — bus 0, chip select 0
func Device(path: string, cfg: spi.Config) -> (Device, Error)

// ── Device Methods ────────────────────────────────────────────────────────────
// Full-duplex — SPI always sends and receives simultaneously
func (d: Device) Transfer(tx: *const uint8, rx: *uint8, len: uint32) -> ((), Error)

// Half-duplex convenience paths
func (d: Device) Write(src: *const uint8, len: uint32) -> ((), Error)
func (d: Device) Read(dest: *uint8, len: uint32) -> ((), Error)

// Register read/write — same pattern as I2C, also common on SPI sensors
func (d: Device) WriteReg(reg: uint8, value: uint8) -> ((), Error)
func (d: Device) ReadReg(reg: uint8, dest: *uint8, len: uint32) -> ((), Error)

func (d: Device) Close() -> ((), Error)

```

**Example — write to an SPI display (SSD1306 OLED):**

```vertex
func clearDisplay() -> ((), spi.Error) {
    let cfg = spi.Config{
        SpeedHz:     8_000_000,
        Mode:        .Mode0,
        BitOrder:    .MSBFirst,
        BitsPerWord: 8,
    }

    let display = spi.Device(path: "/dev/spidev0.0", cfg: cfg)?
    defer display.delete()

    // SSD1306 command: set entire display on
    var cmd: [uint8; 2] = [0x00, 0xA5]
    display.Write(src: &cmd as *const uint8, len: 2)?

    // full-duplex transfer — send command bytes, capture any status in rx
    var tx: [uint8; 4] = [0x00, 0x01, 0x02, 0x03]
    var rx: [uint8; 4]
    display.Transfer(tx: &tx as *const uint8, rx: &rx as *uint8, len: 4)?

    return ((), .None)
}

```

---

## `hw/audio`

Audio is the most real-time sensitive interface. The API gives the developer a raw PCM buffer and gets out of the way — no codecs, no hidden resampling, no format negotiation.

```vertex
import "hw/audio"

// ── Configuration ─────────────────────────────────────────────────────────────
enum SampleFormat {
    case Int16      // 16-bit signed integer PCM
    case Int32      // 32-bit signed integer PCM
    case Float32    // 32-bit float PCM
}

enum Direction {
    case Playback, Capture
}

struct Config {
    SampleRate:   uint32           // 44100, 48000, 96000, etc.
    Channels:     uint8            // 1 = mono, 2 = stereo
    Format:       audio.SampleFormat
    BufferFrames: uint32           // latency control — smaller = lower latency, more CPU
}

struct DeviceInfo {
    Name:        string
    Description: string
    MaxChannels: uint8
    Direction:   audio.Direction
}

enum Error {
    case None, DeviceNotFound, FormatUnsupported, Underrun,
         Overrun, PermissionDenied, DeviceBusy
}

// ── Discovery ─────────────────────────────────────────────────────────────────
func Enumerate(dir: audio.Direction) -> ([DeviceInfo], Error)    // heap, caller owns

// ── Constructors ──────────────────────────────────────────────────────────────
// name: "default", "hw:0,0", etc. — empty string = system default
func Output(name: string, cfg: audio.Config) -> (Output, Error)
func Input(name: string, cfg: audio.Config) -> (Input, Error)

// ── Output Methods ────────────────────────────────────────────────────────────
// Write exactly BufferFrames * Channels samples — blocks until buffer is consumed
func (o: Output) Write(src: *const void, frames: uint32) -> (uint32, Error)
func (o: Output) Drain() -> ((), Error)      // flush remaining samples to hardware
func (o: Output) Pause() -> ((), Error)
func (o: Output) Resume() -> ((), Error)
func (o: Output) Close() -> ((), Error)

// ── Input Methods ─────────────────────────────────────────────────────────────
// Read exactly BufferFrames * Channels samples — blocks until buffer is full
func (i: Input) Read(dest: *void, frames: uint32) -> (uint32, Error)
func (i: Input) Pause() -> ((), Error)
func (i: Input) Resume() -> ((), Error)
func (i: Input) Close() -> ((), Error)

```

**Example — generate a 440 Hz sine wave:**

```vertex
import "hw/audio"

func playTone() -> ((), audio.Error) {
    let cfg = audio.Config{
        SampleRate:   48000,
        Channels:     1,
        Format:       .Float32,
        BufferFrames: 512,
    }

    let out = audio.Output(name: "", cfg: cfg)?
    defer out.delete()

    var buf: [float32; 512]
    var phase: float32 = 0.0
    let increment: float32 = 2.0 * 3.14159 * 440.0 / 48000.0

    var frame: uint32 = 0
    while frame < 48000 {    // 1 second of audio
        var i: uint32 = 0
        while i < 512 {
            buf[i] = libm.sinf(phase) * 0.5    // 50% amplitude
            phase   = phase + increment
            i       = i + 1
        }

        let _ = out.Write(src: &buf as *const void, frames: 512)?
        frame = frame + 512
    }

    out.Drain()?
    return ((), .None)
}

```

**Example — loopback capture to playback:**

```vertex
func loopback() -> ((), audio.Error) {
    let cfg = audio.Config{
        SampleRate:   48000,
        Channels:     2,
        Format:       .Int16,
        BufferFrames: 256,
    }

    let input  = audio.Input(name: "default", cfg: cfg)?
    defer input.delete()

    let output = audio.Output(name: "default", cfg: cfg)?
    defer output.delete()

    // stereo int16: 256 frames × 2 channels = 512 samples
    var buf: [int16; 512]

    while true {
        let _ = input.Read(dest: &buf as *void, frames: 256)?
        let _ = output.Write(src: &buf as *const void, frames: 256)?
    }

    return ((), .None)
}

```

---

## `media/codec`

All codecs share the same structural pattern: a `Config` struct into a constructor, an `Encoder` and `Decoder` as separate types, frame-at-a-time I/O on caller-owned buffers. Codecs never allocate on the hot path.

---

### `media/codec/opus`

```vertex
import "media/codec/opus"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Application {
    case VoIP       // optimised for voice, noise suppression active
    case Audio      // optimised for music and general audio
    case LowDelay   // minimises algorithmic delay, no LPC
}

enum Bitrate {
    case Auto
    case Fixed(uint32)    // bits per second, e.g. 64_000, 128_000
}

struct EncoderConfig {
    SampleRate:  uint32             // 8000, 12000, 16000, 24000, 48000
    Channels:    uint8              // 1 = mono, 2 = stereo
    Application: opus.Application
    Bitrate:     opus.Bitrate
    FrameSizeMs: uint32             // 2.5, 5, 10, 20, 40, 60
}

struct DecoderConfig {
    SampleRate: uint32
    Channels:   uint8
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedPacket,
         InvalidFrameSize, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: opus.EncoderConfig) -> (Encoder, Error)
func Decoder(cfg: opus.DecoderConfig) -> (Decoder, Error)

// ── Encoder Methods ───────────────────────────────────────────────────────────
// pcm is interleaved int16 samples: frames * channels
// dest receives the compressed packet — max 4000 bytes per Opus spec
func (e: Encoder) Encode(pcm: *const int16, frames: uint32, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) SetBitrate(bps: uint32) -> ((), Error)
func (e: Encoder) SetDTX(enabled: bool) -> ((), Error)     // discontinuous transmission
func (e: Encoder) ResetState() -> ((), Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
// dest receives interleaved int16 PCM — allocate frames * channels * 2 bytes
func (d: Decoder) Decode(src: *const uint8, srcLen: uint32, dest: *int16, frames: uint32) -> (uint32, Error)

// packet loss concealment — synthesises a replacement frame when src is nil
func (d: Decoder) DecodePLC(dest: *int16, frames: uint32) -> (uint32, Error)

func (d: Decoder) ResetState() -> ((), Error)
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/aac`

```vertex
import "media/codec/aac"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Profile {
    case LC      // Low Complexity — broadest device support
    case HE      // High Efficiency v1 — SBR, good at low bitrates
    case HEv2    // High Efficiency v2 — SBR + PS, stereo at very low bitrates
}

enum Container {
    case Raw     // raw ADTS frames — for streaming (HLS, RTMP)
    case ADTS    // self-framing — each packet carries its own header
}

struct EncoderConfig {
    SampleRate: uint32
    Channels:   uint8
    Bitrate:    uint32          // bits per second
    Profile:    aac.Profile
    Container:  aac.Container
}

struct DecoderConfig {
    Container: aac.Container
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedFrame,
         UnsupportedProfile, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: aac.EncoderConfig) -> (Encoder, Error)
func Decoder(cfg: aac.DecoderConfig) -> (Decoder, Error)

// ── Encoder Methods ───────────────────────────────────────────────────────────
// AAC frame size is always 1024 samples per channel
func (e: Encoder) Encode(pcm: *const int16, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Decode(src: *const uint8, srcLen: uint32, dest: *int16, maxFrames: uint32) -> (uint32, Error)
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/flac`

```vertex
import "media/codec/flac"

// ── Configuration ─────────────────────────────────────────────────────────────
struct EncoderConfig {
    SampleRate:  uint32
    Channels:    uint8
    BitDepth:    uint8    // 16, 24
    Compression: uint8    // 0 (fastest) – 8 (smallest), default 5
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedStream,
         SeekFailed, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: flac.EncoderConfig) -> (Encoder, Error)
func Decoder() -> (Decoder, Error)    // no config — format is self-describing

// ── Encoder Methods ───────────────────────────────────────────────────────────
func (e: Encoder) Encode(pcm: *const int32, frames: uint32, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) Flush(dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
func (d: Decoder) Decode(dest: *int32, maxFrames: uint32) -> (uint32, Error)
func (d: Decoder) Seek(sampleOffset: uint64) -> ((), Error)

// metadata accessors — valid after the first successful Decode call
func (d: Decoder) SampleRate() -> uint32
func (d: Decoder) Channels() -> uint8
func (d: Decoder) BitDepth() -> uint8
func (d: Decoder) TotalSamples() -> uint64

func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/vorbis`

```vertex
import "media/codec/vorbis"

enum Error {
    case None, CorruptedStream, BadPacket, NotVorbis, InternalError
}

// ── Constructor ───────────────────────────────────────────────────────────────
func Decoder() -> (Decoder, Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
func (d: Decoder) Decode(dest: *float32, maxFrames: uint32) -> (uint32, Error)
func (d: Decoder) SampleRate() -> uint32
func (d: Decoder) Channels() -> uint8
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/h264`

```vertex
import "media/codec/h264"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Profile {
    case Baseline    // broadest compatibility, no B-frames
    case Main
    case High
}

enum RateControl {
    case CBR(uint32)    // constant bitrate, bps
    case VBR(uint32)    // variable bitrate, target bps
    case CQP(uint8)     // constant quantiser 0–51, lower = better quality
}

struct EncoderConfig {
    Width:            uint32
    Height:           uint32
    FrameRateNum:     uint32      // numerator
    FrameRateDen:     uint32      // denominator — e.g. 30000/1001 for 29.97
    Profile:          h264.Profile
    RateControl:      h264.RateControl
    KeyframeInterval: uint32      // IDR period in frames, 0 = encoder decides
}

enum NALType {
    case NonIDR, IDR, SEI, SPS, PPS, AUD, Filler
}

struct NALUnit {
    Type: h264.NALType
    Data: [uint8]     // heap-allocated, caller owns
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedBitstream,
         UnsupportedProfile, HardwareUnavailable, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: h264.EncoderConfig) -> (Encoder, Error)
func Decoder() -> (Decoder, Error)    // no config — H.264 is self-describing via SPS/PPS NAL units

// ── Encoder Methods ───────────────────────────────────────────────────────────
// yuv is a planar YUV 4:2:0 frame — width * height * 3 / 2 bytes
func (e: Encoder) Encode(yuv: *const uint8, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) ForceKeyframe() -> ((), Error)
func (e: Encoder) SetBitrate(bps: uint32) -> ((), Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
// Feed a single NAL unit — Annex B or AVCC detected automatically
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
// Returns decoded YUV 4:2:0 frame if one is ready; 0 bytes otherwise
func (d: Decoder) Decode(dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (d: Decoder) Width() -> uint32
func (d: Decoder) Height() -> uint32
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/h265`

```vertex
import "media/codec/h265"

enum Profile {
    case Main                // 8-bit 4:2:0
    case Main10              // 10-bit 4:2:0
    case MainStillPicture
}

enum RateControl {
    case CBR(uint32)
    case VBR(uint32)
    case CQP(uint8)
}

struct EncoderConfig {
    Width:            uint32
    Height:           uint32
    FrameRateNum:     uint32
    FrameRateDen:     uint32
    Profile:          h265.Profile
    RateControl:      h265.RateControl
    KeyframeInterval: uint32
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedBitstream,
         UnsupportedProfile, HardwareUnavailable, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: h265.EncoderConfig) -> (Encoder, Error)
func Decoder() -> (Decoder, Error)

// ── Encoder Methods ───────────────────────────────────────────────────────────
func (e: Encoder) Encode(yuv: *const uint8, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) ForceKeyframe() -> ((), Error)
func (e: Encoder) SetBitrate(bps: uint32) -> ((), Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
func (d: Decoder) Decode(dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (d: Decoder) Width() -> uint32
func (d: Decoder) Height() -> uint32
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/vp8` and `media/codec/vp9`

```vertex
import "media/codec/vp9"    // replace with "media/codec/vp8" for VP8

enum RateControl {
    case CBR(uint32)
    case VBR(uint32)
    case CQ(uint8)      // constrained quality 0–63
}

struct EncoderConfig {
    Width:            uint32
    Height:           uint32
    FrameRateNum:     uint32
    FrameRateDen:     uint32
    RateControl:      vp9.RateControl
    KeyframeInterval: uint32
    Threads:          uint8    // 0 = auto
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedBitstream, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: vp9.EncoderConfig) -> (Encoder, Error)
func Decoder() -> (Decoder, Error)

// ── Encoder Methods ───────────────────────────────────────────────────────────
func (e: Encoder) Encode(yuv: *const uint8, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) ForceKeyframe() -> ((), Error)
func (e: Encoder) SetBitrate(bps: uint32) -> ((), Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
func (d: Decoder) Decode(dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (d: Decoder) Width() -> uint32
func (d: Decoder) Height() -> uint32
func (d: Decoder) Close() -> ((), Error)

```

---

### `media/codec/av1`

```vertex
import "media/codec/av1"

// ── Configuration ─────────────────────────────────────────────────────────────
enum Profile {
    case Main            // 8/10-bit 4:2:0
    case High            // 8/10-bit 4:4:4
    case Professional
}

enum RateControl {
    case CBR(uint32)
    case VBR(uint32)
    case CQ(uint8)       // 0–63, lower = better quality
}

struct EncoderConfig {
    Width:            uint32
    Height:           uint32
    FrameRateNum:     uint32
    FrameRateDen:     uint32
    Profile:          av1.Profile
    RateControl:      av1.RateControl
    KeyframeInterval: uint32
    Speed:            uint8     // 0 (best quality) – 12 (fastest), default 6
    Threads:          uint8     // 0 = auto
}

enum Error {
    case None, InvalidConfig, BufferTooSmall, CorruptedBitstream,
         HardwareUnavailable, InternalError
}

// ── Constructors ──────────────────────────────────────────────────────────────
func Encoder(cfg: av1.EncoderConfig) -> (Encoder, Error)
func Decoder() -> (Decoder, Error)

// ── Encoder Methods ───────────────────────────────────────────────────────────
func (e: Encoder) Encode(yuv: *const uint8, dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (e: Encoder) ForceKeyframe() -> ((), Error)
func (e: Encoder) SetBitrate(bps: uint32) -> ((), Error)
func (e: Encoder) Close() -> ((), Error)

// ── Decoder Methods ───────────────────────────────────────────────────────────
func (d: Decoder) Feed(src: *const uint8, len: uint32) -> ((), Error)
func (d: Decoder) Decode(dest: *uint8, maxLen: uint32) -> (uint32, Error)
func (d: Decoder) Width() -> uint32
func (d: Decoder) Height() -> uint32
func (d: Decoder) Close() -> ((), Error)