namespace bluetooth

use native
use windows

// ---------------------------------------------------------------------------
// Opaque handles
//
// Every one of these is `HANDLE` — void* — at the ABI. Giving each its own
// `declare struct` costs nothing at link time (Windows x64 has one calling
// convention and no name decoration) and stops a radio-find handle from being
// passed to BluetoothFindDeviceClose, which the C header cannot.
// ---------------------------------------------------------------------------

declare struct Radio
declare struct RadioFind
declare struct DeviceFind
declare struct StdHandle

// ---------------------------------------------------------------------------
// Boundary structs
//
// Win32's dwSize idiom is doing the verification here. The compiler never reads
// bluetoothapis.h, so nothing checks that these layouts are right — but every
// one of these calls rejects a struct whose leading dwSize doesn't match what
// the OS expects. A wrong layout returns ERROR_REVISION_MISMATCH on the first
// call instead of corrupting memory quietly. Write `sizeof`, never a constant.
// ---------------------------------------------------------------------------

const BLUETOOTH_MAX_NAME_SIZE: usize = 248

// BLUETOOTH_ADDRESS is `#pragma pack(1)` around a union of ULONGLONG and
// BYTE[6]. Size 8, alignment 1 — the packing is load-bearing, since it moves
// this member to offset 4 in both structs below rather than offset 8.
@packed struct BLUETOOTH_ADDRESS {
  ull: uint64

  constructor() {
    this.ull = 0
  }
}

struct SYSTEMTIME {
  wYear: uint16
  wMonth: uint16
  wDayOfWeek: uint16
  wDay: uint16
  wHour: uint16
  wMinute: uint16
  wSecond: uint16
  wMilliseconds: uint16

  constructor() {
    this.wYear = 0
    this.wMonth = 0
    this.wDayOfWeek = 0
    this.wDay = 0
    this.wHour = 0
    this.wMinute = 0
    this.wSecond = 0
    this.wMilliseconds = 0
  }
}

struct BLUETOOTH_FIND_RADIO_PARAMS {
  dwSize: uint32

  constructor() {
    this.dwSize = uint32(sizeof<BLUETOOTH_FIND_RADIO_PARAMS>())
  }
}

struct BLUETOOTH_RADIO_INFO {
  dwSize: uint32
  address: BLUETOOTH_ADDRESS
  szName: array<uint16, 248>
  ulClassofDevice: uint32
  lmpSubversion: uint16
  manufacturer: uint16

  constructor() {
    this.dwSize = uint32(sizeof<BLUETOOTH_RADIO_INFO>())
    this.address = BLUETOOTH_ADDRESS()
    for i in 0..248 {
      this.szName[i] = 0
    }
    this.ulClassofDevice = 0
    this.lmpSubversion = 0
    this.manufacturer = 0
  }
}

// Note every BOOL here is `int32`, not `bool`. Vertex's `bool` is one byte with
// two valid patterns; Win32's BOOL is a four-byte int where anything nonzero is
// true. They are not the same type and there is no conversion between them —
// these are compared with `!== 0` at the point of use.
struct BLUETOOTH_DEVICE_SEARCH_PARAMS {
  dwSize: uint32
  fReturnAuthenticated: int32
  fReturnRemembered: int32
  fReturnUnknown: int32
  fReturnConnected: int32
  fIssueInquiry: int32
  cTimeoutMultiplier: uint8
  hRadio: mutable_ptr<Radio>

  constructor(radio: mutable_ptr<Radio>) {
    this.dwSize = uint32(sizeof<BLUETOOTH_DEVICE_SEARCH_PARAMS>())
    this.fReturnAuthenticated = 1
    this.fReturnRemembered = 1
    this.fReturnUnknown = 1
    this.fReturnConnected = 1
    this.fIssueInquiry = 1
    this.cTimeoutMultiplier = 4      // 4 × 1.28s ≈ 5s inquiry
    this.hRadio = radio
  }
}

struct BLUETOOTH_DEVICE_INFO {
  dwSize: uint32
  Address: BLUETOOTH_ADDRESS
  ulClassofDevice: uint32
  fConnected: int32
  fRemembered: int32
  fAuthenticated: int32
  stLastSeen: SYSTEMTIME
  stLastUsed: SYSTEMTIME
  szName: array<uint16, 248>

  constructor() {
    this.dwSize = uint32(sizeof<BLUETOOTH_DEVICE_INFO>())
    this.Address = BLUETOOTH_ADDRESS()
    this.ulClassofDevice = 0
    this.fConnected = 0
    this.fRemembered = 0
    this.fAuthenticated = 0
    this.stLastSeen = SYSTEMTIME()
    this.stLastUsed = SYSTEMTIME()
    for i in 0..248 {
      this.szName[i] = 0
    }
  }
}

// Class of Device is 24 significant bits inside a ULONG. This is the bitfield
// case native.md §3 describes — unsigned sized type, inside a struct, reached
// by bit_cast rather than by shifting at every site.
struct ClassOfDevice {
  @bits(2) format: uint32
  @bits(6) minor: uint32
  @bits(5) major: uint32
  @bits(11) service: uint32
  @bits(8) reserved: uint32
}

// ---------------------------------------------------------------------------
// bthprops
//
// Windows has one resolver — the library search path — so the specifier is
// bare and undecorated. `bthprops.lib`.
// ---------------------------------------------------------------------------

declare module "bthprops" {
  export func BluetoothFindFirstRadio(
      params: const_ptr<BLUETOOTH_FIND_RADIO_PARAMS>,
      out: mutable_ptr<mutable_ptr<Radio> | null>): mutable_ptr<RadioFind> | null

  export func BluetoothFindNextRadio(
      find: mutable_ptr<RadioFind>,
      out: mutable_ptr<mutable_ptr<Radio> | null>): int32

  export func BluetoothFindRadioClose(find: mutable_ptr<RadioFind>): int32

  export func BluetoothGetRadioInfo(
      radio: mutable_ptr<Radio>,
      info: mutable_ptr<BLUETOOTH_RADIO_INFO>): uint32

  export func BluetoothFindFirstDevice(
      params: const_ptr<BLUETOOTH_DEVICE_SEARCH_PARAMS>,
      info: mutable_ptr<BLUETOOTH_DEVICE_INFO>): mutable_ptr<DeviceFind> | null

  export func BluetoothFindNextDevice(
      find: mutable_ptr<DeviceFind>,
      info: mutable_ptr<BLUETOOTH_DEVICE_INFO>): int32

  export func BluetoothFindDeviceClose(find: mutable_ptr<DeviceFind>): int32
}

declare module "kernel32" {
  export func GetStdHandle(n: uint32): mutable_ptr<StdHandle> | null
  export func CloseHandle(h: void_ptr): int32
  export func GetLastError(): uint32

  export func WriteFile(h: mutable_ptr<StdHandle>,
                        buf: const_ptr<byte>,
                        n: uint32,
                        written: mutable_ptr<uint32>,
                        overlapped: void_ptr | null): int32

  export func WideCharToMultiByte(cp: uint32, flags: uint32,
                                  wide: const_ptr<uint16>, wideLen: int32,
                                  out: mutable_ptr<byte>, outLen: int32,
                                  defaultChar: const_ptr<byte> | null,
                                  usedDefault: mutable_ptr<int32> | null): int32
}

const STD_OUTPUT_HANDLE: uint32 = 0xFFFF_FFF5
const ERROR_SUCCESS: uint32 = 0
const CP_UTF8: uint32 = 65001

// ---------------------------------------------------------------------------
// Handle wrappers
//
// Three separate close functions, three separate destructors. Same shape as the
// socket in tcp_server.vs, and the same payoff: every error path below is a
// bare `return`.
// ---------------------------------------------------------------------------

class RadioFindHandle {
  readonly h: mutable_ptr<RadioFind>
  constructor(h: mutable_ptr<RadioFind>) { this.h = h }
  destructor() { BluetoothFindRadioClose(this.h) }
}

class DeviceFindHandle {
  readonly h: mutable_ptr<DeviceFind>
  constructor(h: mutable_ptr<DeviceFind>) { this.h = h }
  destructor() { BluetoothFindDeviceClose(this.h) }
}

class RadioHandle {
  readonly h: mutable_ptr<Radio>
  constructor(h: mutable_ptr<Radio>) { this.h = h }
  destructor() { CloseHandle(this.h as void_ptr) }
}

// ---------------------------------------------------------------------------
// Output
//
// There is no bridge from `string` to `const_ptr<byte>`, so everything here is
// bytes assembled by hand. ASCII codes are spelled numerically because Vertex
// has no character literal — `'A'` is a string in TS and stayed one here.
// ---------------------------------------------------------------------------

func hexDigit(v: uint32): uint8 {
  return v < 10 ? uint8(48 + v) : uint8(87 + v)
}

func put(out: mutable_ptr<StdHandle>, buf: const_ptr<byte>, n: uint32): void {
  var written: uint32 = 0
  WriteFile(out, buf, n, addressof(written), null)
}

func newline(out: mutable_ptr<StdHandle>): void {
  var nl: array<byte, 2> = array<byte, 2>()
  nl[0] = 13
  nl[1] = 10
  put(out, addressof(nl[0]) as const_ptr<byte>, 2)
}

// 11:22:33:44:55:66 — MSB first, which is the display convention and the
// reverse of the union's byte order.
func putAddress(out: mutable_ptr<StdHandle>, ull: uint64): void {
  var buf: array<byte, 17> = array<byte, 17>()
  var i: usize = 0
  var b: int32 = 5

  while b >= 0 {
    let v = uint32((ull >> uint64(b * 8)) & 0xff)
    buf[i] = hexDigit(v >> 4)
    buf[i + 1] = hexDigit(v & 0xf)
    i += 2
    if b > 0 {
      buf[i] = 58            // ':'
      i += 1
    }
    b -= 1
  }

  put(out, addressof(buf[0]) as const_ptr<byte>, uint32(i))
}

func putWide(out: mutable_ptr<StdHandle>, wide: const_ptr<uint16>): void {
  var buf: array<byte, 512> = array<byte, 512>()

  let n = WideCharToMultiByte(CP_UTF8, 0, wide, -1,
                              addressof(buf[0]), 512, null, null)
  if n <= 1 {
    return                   // -1 on failure, 1 for the NUL alone
  }

  put(out, addressof(buf[0]) as const_ptr<byte>, uint32(n - 1))
}

func putUint(out: mutable_ptr<StdHandle>, v: uint32): void {
  var buf: array<byte, 10> = array<byte, 10>()
  var n: usize = 0
  var x = v

  if x === 0 {
    buf[0] = 48
    put(out, addressof(buf[0]) as const_ptr<byte>, 1)
    return
  }

  while x > 0 {
    buf[n] = uint8(48 + (x % 10))
    x /= 10
    n += 1
  }

  var rbuf: array<byte, 10> = array<byte, 10>()
  for i in 0..n {
    rbuf[i] = buf[n - 1 - i]
  }

  put(out, addressof(rbuf[0]) as const_ptr<byte>, uint32(n))
}

// ---------------------------------------------------------------------------
// Enumeration
// ---------------------------------------------------------------------------

func printDevice(out: mutable_ptr<StdHandle>,
                 dev: readonly BLUETOOTH_DEVICE_INFO): void {
  let cod = bit_cast<ClassOfDevice>(dev.ulClassofDevice)

  putAddress(out, dev.Address.ull)

  var sep: array<byte, 2> = array<byte, 2>()
  sep[0] = 32                // ' '
  sep[1] = 32
  put(out, addressof(sep[0]) as const_ptr<byte>, 2)

  putWide(out, addressof(dev.szName[0]) as const_ptr<uint16>)
  put(out, addressof(sep[0]) as const_ptr<byte>, 2)

  putUint(out, cod.major)
  sep[0] = 47                // '/'
  put(out, addressof(sep[0]) as const_ptr<byte>, 1)
  putUint(out, cod.minor)

  if dev.fConnected !== 0 {
    var tag: array<byte, 6> = array<byte, 6>()
    tag[0] = 32
    tag[1] = 91              // '['
    tag[2] = 111             // 'o'
    tag[3] = 110             // 'n'
    tag[4] = 93              // ']'
    put(out, addressof(tag[0]) as const_ptr<byte>, 5)
  }

  newline(out)
}

func scanRadio(out: mutable_ptr<StdHandle>, radio: mutable_ptr<Radio>): void {
  var info = BLUETOOTH_RADIO_INFO()

  if BluetoothGetRadioInfo(radio, addressof(info)) === ERROR_SUCCESS {
    putWide(out, addressof(info.szName[0]) as const_ptr<uint16>)
    newline(out)
  }

  var search = BLUETOOTH_DEVICE_SEARCH_PARAMS(radio)
  var dev = BLUETOOTH_DEVICE_INFO()

  if let find = BluetoothFindFirstDevice(
        addressof(search) as const_ptr<BLUETOOTH_DEVICE_SEARCH_PARAMS>,
        addressof(dev)) {

    let guard = DeviceFindHandle(find)

    while true {
      printDevice(out, dev)
      if BluetoothFindNextDevice(find, addressof(dev)) === 0 {
        return             // guard's destructor closes the enumeration
      }
    }
  }
}

func main(): int32 {
  if let out = GetStdHandle(STD_OUTPUT_HANDLE) {
    var params = BLUETOOTH_FIND_RADIO_PARAMS()
    var radio: mutable_ptr<Radio> | null = null

    if let find = BluetoothFindFirstRadio(
          addressof(params) as const_ptr<BLUETOOTH_FIND_RADIO_PARAMS>,
          addressof(radio)) {

      let guard = RadioFindHandle(find)

      while true {
        if let r = radio {
          let owned = RadioHandle(r)
          scanRadio(out, r)
        }

        radio = null
        if BluetoothFindNextRadio(find, addressof(radio)) === 0 {
          return 0
        }
      }
    }

    return int32(GetLastError())
  }

  return 1
}