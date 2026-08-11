namespace main // File-scoped namespace declarations replace general scoping constructs[cite: 4].

// 1. Dispatchable handles.
// Introduces layout-free types whose definitions live in C[cite: 3].
declare struct VkInstance_T
declare struct VkPhysicalDevice_T
declare struct VkDevice_T
declare struct VkQueue_T

// Vulkan's own typedefs, preserved as aliases to pointers.
type VkInstance = mutable_ptr<VkInstance_T>
type VkPhysicalDevice = mutable_ptr<VkPhysicalDevice_T>
type VkDevice = mutable_ptr<VkDevice_T>
type VkQueue = mutable_ptr<VkQueue_T>

// Non-dispatchable handles (VkBuffer, VkImage, ...) are scalars.
type VkDeviceMemory = uint64

// 2. By-value structs.
// Compile-time values require the const keyword[cite: 4].
const VK_STRUCTURE_TYPE_APPLICATION_INFO: uint32 = uint32(0)
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO: uint32 = uint32(1)
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO: uint32 = uint32(2)
const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO: uint32 = uint32(3)

const VK_SUCCESS: int32 = int32(0)
const VK_QUEUE_GRAPHICS_BIT: uint32 = uint32(0x1)
const VK_MAX_PHYSICAL_DEVICES: usize = usize(8)

// Structs are value types initialized by direct call[cite: 10].
struct VkApplicationInfo {
  // readonly freezes a field's data[cite: 10].
  readonly sType: uint32
  readonly pNext: void_ptr | null
  readonly pApplicationName: const_ptr<byte> | null
  readonly applicationVersion: uint32
  readonly pEngineName: const_ptr<byte> | null
  readonly engineVersion: uint32
  readonly apiVersion: uint32

  // Initialization hooks use the constructor keyword[cite: 4].
  constructor(name: const_ptr<byte> | null, engine: const_ptr<byte> | null, api: uint32) {
    this.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
    // nullptr() is replaced by null in the new spec[cite: 8].
    this.pNext = null
    this.pApplicationName = name
    this.applicationVersion = uint32(1)
    this.pEngineName = engine
    this.engineVersion = uint32(1)
    this.apiVersion = api
  }
}

struct VkInstanceCreateInfo {
  readonly sType: uint32
  readonly pNext: void_ptr | null
  readonly flags: uint32
  readonly pApplicationInfo: const_ptr<VkApplicationInfo> | null
  readonly enabledLayerCount: uint32
  readonly ppEnabledLayerNames: const_ptr<const_ptr<byte>> | null
  readonly enabledExtensionCount: uint32
  readonly ppEnabledExtensionNames: const_ptr<const_ptr<byte>> | null

  constructor(app: const_ptr<VkApplicationInfo> | null) {
    this.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    this.pNext = null
    this.flags = uint32(0)
    this.pApplicationInfo = app
    this.enabledLayerCount = uint32(0)
    this.ppEnabledLayerNames = null
    this.enabledExtensionCount = uint32(0)
    this.ppEnabledExtensionNames = null
  }
}

struct VkQueueFamilyProperties {
  queueFlags: uint32
  queueCount: uint32
  timestampValidBits: uint32
  minImageTransferGranularityWidth: uint32
  minImageTransferGranularityHeight: uint32
  minImageTransferGranularityDepth: uint32

  constructor() {
    this.queueFlags = uint32(0)
    this.queueCount = uint32(0)
    this.timestampValidBits = uint32(0)
    this.minImageTransferGranularityWidth = uint32(0)
    this.minImageTransferGranularityHeight = uint32(0)
    this.minImageTransferGranularityDepth = uint32(0)
  }
}

struct VkDeviceQueueCreateInfo {
  readonly sType: uint32
  readonly pNext: void_ptr | null
  readonly flags: uint32
  readonly queueFamilyIndex: uint32
  readonly queueCount: uint32
  readonly pQueuePriorities: const_ptr<float32> | null

  constructor(family: uint32, priorities: const_ptr<float32> | null) {
    this.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    this.pNext = null
    this.flags = uint32(0)
    this.queueFamilyIndex = family
    this.queueCount = uint32(1)
    this.pQueuePriorities = priorities
  }
}

struct VkDeviceCreateInfo {
  readonly sType: uint32
  readonly pNext: void_ptr | null
  readonly flags: uint32
  readonly queueCreateInfoCount: uint32
  readonly pQueueCreateInfos: const_ptr<VkDeviceQueueCreateInfo> | null
  readonly enabledLayerCount: uint32
  readonly ppEnabledLayerNames: const_ptr<const_ptr<byte>> | null
  readonly enabledExtensionCount: uint32
  readonly ppEnabledExtensionNames: const_ptr<const_ptr<byte>> | null
  readonly pEnabledFeatures: void_ptr | null

  constructor(queues: const_ptr<VkDeviceQueueCreateInfo> | null) {
    this.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    this.pNext = null
    this.flags = uint32(0)
    this.queueCreateInfoCount = uint32(1)
    this.pQueueCreateInfos = queues
    this.enabledLayerCount = uint32(0)
    this.ppEnabledLayerNames = null
    this.enabledExtensionCount = uint32(0)
    this.ppEnabledExtensionNames = null
    this.pEnabledFeatures = null
  }
}

// 3. The library.
declare module "vulkan" {
  // Functions in an extern block utilize the func keyword and explicit union types for nullability[cite: 3, 4].
  export func vkCreateInstance(
    info: const_ptr<VkInstanceCreateInfo>,
    allocator: void_ptr | null,
    out: mutable_ptr<VkInstance | null>
  ): int32
  
  export func vkDestroyInstance(instance: VkInstance | null, allocator: void_ptr | null): void

  export func vkEnumeratePhysicalDevices(
    instance: VkInstance | null,
    count: mutable_ptr<uint32>,
    devices: mutable_ptr<VkPhysicalDevice | null> | null
  ): int32

  export func vkGetPhysicalDeviceQueueFamilyProperties(
    device: VkPhysicalDevice,
    count: mutable_ptr<uint32>,
    props: mutable_ptr<VkQueueFamilyProperties> | null
  ): void

  export func vkCreateDevice(
    physical: VkPhysicalDevice,
    info: const_ptr<VkDeviceCreateInfo>,
    allocator: void_ptr | null,
    out: mutable_ptr<VkDevice | null>
  ): int32
  
  export func vkDestroyDevice(device: VkDevice | null, allocator: void_ptr | null): void
  export func vkDeviceWaitIdle(device: VkDevice): int32

  export func vkGetDeviceQueue(
    device: VkDevice,
    family: uint32,
    index: uint32,
    out: mutable_ptr<VkQueue | null>
  ): void
}

// 4. Wrappers.
// Reference types with inline refcount headers[cite: 10].
class Instance {
  handle: VkInstance | null
  
  constructor(handle: VkInstance | null) { 
    this.handle = handle 
  }
  
  // Deterministic scope-bound teardown hook[cite: 5].
  destructor() { 
    vkDestroyInstance(this.handle, null) 
  }
}

class Device {
  handle: VkDevice | null
  parent: shared_ptr<Instance> 

  constructor(handle: VkDevice | null, parent: shared_ptr<Instance>) {
    this.handle = handle
    this.parent = parent
  }

  destructor() {
    // Parenthesis-free control flow unwraps with if let[cite: 4].
    if let h = this.handle {
      vkDeviceWaitIdle(h)
    }
    vkDestroyDevice(this.handle, null)
  }

  queue(family: uint32): VkQueue | null {
    // mutable variable bindings use var[cite: 4].
    var q: VkQueue | null = null
    if let h = this.handle {
      // addressof accesses the stack lvalue to produce a raw pointer[cite: 9].
      vkGetDeviceQueue(h, family, uint32(0), addressof(q))
    }
    return q
  }
}

// 5. Setup.
// A mock cstr function for the byte pointers to replace missing behavior.
func cstr(s: string): const_ptr<byte> | null {
  return null
}

func pickGraphicsFamily(physical: VkPhysicalDevice): uint32 | null {
  // mutable bindings utilize var since const is compile-time only[cite: 4].
  var count: uint32 = uint32(0)
  vkGetPhysicalDeviceQueueFamilyProperties(physical, addressof(count), null)
  
  if count === uint32(0) { 
    return null 
  }

  // Value-typed inline fixed-length storage[cite: 6].
  var props: FixedArray<VkQueueFamilyProperties, 16> = FixedArray<VkQueueFamilyProperties, 16>()
  
  if usize(count) > usize(16) { 
    count = uint32(16) 
  }
  
  vkGetPhysicalDeviceQueueFamilyProperties(physical, addressof(count), addressof(props[usize(0)]))

  var i: uint32 = uint32(0)
  
  // Parenthesis-free loops[cite: 4].
  while i < count {
    // Array access using usize cast[cite: 6].
    let flags: uint32 = props[usize(i)].queueFlags
    if (flags & VK_QUEUE_GRAPHICS_BIT) !== uint32(0) { 
      return i 
    }
    i = i + uint32(1)
  }
  return null
}

func main(): int32 {
  // local stack structures that will have `addressof` performed on them must use `var` bindings[cite: 9].
  var appInfo: VkApplicationInfo = VkApplicationInfo(
    cstr("vertex-triangle"), cstr("vertex"), uint32(0x00401000)
  )
  
  var instInfo: VkInstanceCreateInfo = VkInstanceCreateInfo(
    pointer_cast<VkApplicationInfo>(addressof(appInfo))
  )

  var rawInstance: VkInstance | null = null
  
  if vkCreateInstance(
    pointer_cast<VkInstanceCreateInfo>(addressof(instInfo)), 
    null, 
    addressof(rawInstance)
  ) !== VK_SUCCESS {
    return 1
  }

  // Unwrap the FFI pointer carefully using if let before promoting to Unmanaged tier pointers[cite: 4].
  if let validInstance = rawInstance {
    // Construction via make_shared inside the Unmanaged tier instead of bare class initialization[cite: 9].
    let instance: shared_ptr<Instance> = make_shared<Instance>(validInstance)
    
    var deviceCount: uint32 = uint32(VK_MAX_PHYSICAL_DEVICES)
    var physicals: FixedArray<VkPhysicalDevice | null, 8> = FixedArray<VkPhysicalDevice | null, 8>()
    
    if vkEnumeratePhysicalDevices(
      validInstance, 
      addressof(deviceCount), 
      addressof(physicals[usize(0)])
    ) !== VK_SUCCESS {
      return 1
    }
    
    if deviceCount === uint32(0) { 
      return 1 
    }

    let physicalOpt: VkPhysicalDevice | null = physicals[usize(0)]
    
    if let physical = physicalOpt {
      let familyOpt: uint32 | null = pickGraphicsFamily(physical)
      
      if let family = familyOpt {
        var priority: float32 = float32(1.0)
        var queueInfo: VkDeviceQueueCreateInfo = VkDeviceQueueCreateInfo(
          family, pointer_cast<float32>(addressof(priority))
        )
        var deviceInfo: VkDeviceCreateInfo = VkDeviceCreateInfo(
          pointer_cast<VkDeviceQueueCreateInfo>(addressof(queueInfo))
        )

        var rawDevice: VkDevice | null = null
        
        if vkCreateDevice(
          physical, 
          pointer_cast<VkDeviceCreateInfo>(addressof(deviceInfo)), 
          null, 
          addressof(rawDevice)
        ) !== VK_SUCCESS {
          return 1
        }
        
        if let validDevice = rawDevice {
          let device: shared_ptr<Device> = make_shared<Device>(validDevice, instance)
          let graphics: VkQueue | null = device.queue(family)
          
          // ... swapchain, pipeline, command buffers, draw ...
        }
      }
    }
  }

  return 0
}