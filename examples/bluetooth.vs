namespace main

use windows // Custom use directives are supported at the file level[cite: 4].

// Late-bound library, resolved via dlopen/dlsym at first use[cite: 3].
declare module "dynamic:bthprops.dll" {
  // Function declarations use the `func` keyword[cite: 4].
  // Value types at the boundary used by C frameworks are ordinary struct declarations[cite: 8].
  export func BluetoothFindFirstDevice(
    searchParams: const_ptr<BluetoothDeviceSearchParams>,
    deviceInfo: mutable_ptr<BluetoothDeviceInfo>
  ): void_ptr | null

  export func BluetoothFindNextDevice(
    hFind: void_ptr,
    deviceInfo: mutable_ptr<BluetoothDeviceInfo>
  ): int32

  export func BluetoothFindDeviceClose(
    hFind: void_ptr
  ): int32
}

// Value type representing the C struct layout[cite: 10].
struct BluetoothDeviceInfo {
  dwSize: uint32
  Address: uint64
  ulClassofDevice: uint32
  fConnected: int32
  fRemembered: int32
  fAuthenticated: int32
  // Inline, fixed-length storage[cite: 6].
  szName: FixedArray<uint16, 248>

  constructor() {
    // Layout introspection query used for size[cite: 6].
    this.dwSize = uint32(sizeof<BluetoothDeviceInfo>())
    this.Address = uint64(0)
    this.ulClassofDevice = uint32(0)
    this.fConnected = 0
    this.fRemembered = 0
    this.fAuthenticated = 0
    this.szName = FixedArray<uint16, 248>()
  }
}

struct BluetoothDeviceSearchParams {
  dwSize: uint32
  fReturnAuthenticated: int32
  fReturnRemembered: int32
  fReturnUnknown: int32
  fReturnConnected: int32
  fIssueInquiry: int32
  cTimeoutMultiplier: uint8
  // Nullable raw pointer[cite: 9].
  hRadio: void_ptr | null

  constructor() {
    this.dwSize = uint32(sizeof<BluetoothDeviceSearchParams>())
    this.fReturnAuthenticated = 1
    this.fReturnRemembered = 1
    this.fReturnUnknown = 1
    this.fReturnConnected = 1
    this.fIssueInquiry = 1
    this.cTimeoutMultiplier = uint8(2)
    this.hRadio = null
  }
}

// Reference type with an inline refcount header[cite: 10].
class BluetoothScanner {
  private handle: void_ptr | null

  constructor() {
    // Structs are initialized by direct call rather than `new`[cite: 10].
    // `var` declares a mutable binding[cite: 4].
    var params: BluetoothDeviceSearchParams = BluetoothDeviceSearchParams()
    var info: BluetoothDeviceInfo = BluetoothDeviceInfo()

    // addressof produces a raw pointer from a stack lvalue[cite: 9].
    this.handle = BluetoothFindFirstDevice(
      pointer_cast<BluetoothDeviceSearchParams>(addressof(params)),
      addressof(info)
    )
  }

  destructor() {
    // Parenthesis-free control flow[cite: 4].
    if this.handle !== null {
      BluetoothFindDeviceClose(this.handle)
    }
  }
}

func main(): int32 {
  // Construction via make_shared is required for Unmanaged-tier pointers rather than implicit `new`[cite: 9].
  let scanner = make_shared<BluetoothScanner>()
  
  return 0
}