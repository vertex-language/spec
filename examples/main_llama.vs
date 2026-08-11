namespace main

// The declare module block is both the declaration and the binder; ES named imports are removed[cite: 3, 8].
// Introduces layout-free types whose definitions live in C[cite: 3].
declare struct llama_model
declare struct llama_context

// Binds a native library and triggers the linker[cite: 3].
declare module "llama" {
  // Functions inside a declare module block are never fallible[cite: 3].
  // Use the `func` keyword for functions[cite: 4].
  export func llama_backend_init(): void
  export func llama_backend_free(): void

  // Declared structs are legal only behind a pointer[cite: 3].
  // C pointers are nullable by default; Vertex bindings must explicitly spell absence via unions[cite: 3].
  export func llama_load_model_from_file(path_model: const_ptr<byte>): mutable_ptr<llama_model> | null
  export func llama_new_context_with_model(model: mutable_ptr<llama_model>): mutable_ptr<llama_context> | null

  export func llama_free(ctx: mutable_ptr<llama_context>): void
  export func llama_free_model(model: mutable_ptr<llama_model>): void
}

// Reference type heap-allocated with an inline refcount header[cite: 10].
class LlamaWrapper {
  // Raw pointers are non-nullable by default; absence is spelled as an explicit union[cite: 9].
  private model: mutable_ptr<llama_model> | null
  private ctx: mutable_ptr<llama_context> | null

  constructor(path: const_ptr<byte>) {
    llama_backend_init()
    
    // Semicolons are removed from the language[cite: 4].
    this.model = llama_load_model_from_file(path)
    
    // Unwraps the nullable result securely using if let, avoiding unsafe null pointer passing[cite: 3, 4].
    if let unwrapped_model = this.model {
      this.ctx = llama_new_context_with_model(unwrapped_model)
    } else {
      this.ctx = null
    }
  }

  // Teardown hook[cite: 4].
  destructor() {
    // Parenthesis-free control flow and if let used to unwrap nullable pointers[cite: 4].
    if let unwrapped_ctx = this.ctx {
      llama_free(unwrapped_ctx)
    }
    
    if let unwrapped_model = this.model {
      llama_free_model(unwrapped_model)
    }
    
    llama_backend_free()
  }
}

func main(): int32 {
  // The only route from an integer to a pointer[cite: 6]. 
  // let is used for immutable block-scoped bindings[cite: 4].
  let mock_addr: mutable_ptr<byte> = pointer_from_address<byte>(usize(0x4002_0000))
  
  // Pointer-to-pointer reinterpretation[cite: 6].
  let path: const_ptr<byte> = pointer_cast<byte>(mock_addr)

  // Object construction uses make_shared in the Unmanaged tier instead of the `new` keyword[cite: 9].
  let llama: shared_ptr<LlamaWrapper> = make_shared<LlamaWrapper>(path)
  
  // int32 numeric primitive return[cite: 7].
  return 0
}