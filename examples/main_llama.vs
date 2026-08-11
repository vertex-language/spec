namespace llama

use native
use linux

// Opaque — definitions live in llama.cpp, and every one of these is only ever
// reached through a pointer.
declare struct llama_model
declare struct llama_context
declare struct llama_vocab
declare struct llama_sampler

// llama_token is int32_t. Aliasing it costs nothing and reads better at the
// call sites below.
// (no `type` alias form in the grammar — spelled int32 throughout)

// llama_batch is passed by value and its layout is public. Pointers into
// caller-owned arrays; nothing here owns anything.
struct llama_batch {
  n_tokens: int32
  token: mutable_ptr<int32> | null
  embd: mutable_ptr<float32> | null
  pos: mutable_ptr<int32> | null
  n_seq_id: mutable_ptr<int32> | null
  seq_id: mutable_ptr<mutable_ptr<int32>> | null
  logits: mutable_ptr<int8> | null
}

declare module "llama" {
  export func llama_backend_init(): void
  export func llama_backend_free(): void

  export func llama_model_free(m: mutable_ptr<llama_model>): void
  export func llama_free(c: mutable_ptr<llama_context>): void

  export func llama_model_get_vocab(
      m: const_ptr<llama_model>): const_ptr<llama_vocab>

  export func llama_vocab_n_tokens(v: const_ptr<llama_vocab>): int32
  export func llama_vocab_is_eog(v: const_ptr<llama_vocab>, t: int32): bool

  export func llama_tokenize(
      v: const_ptr<llama_vocab>,
      text: const_ptr<byte>, text_len: int32,
      out: mutable_ptr<int32>, out_len: int32,
      add_special: bool, parse_special: bool): int32

  export func llama_token_to_piece(
      v: const_ptr<llama_vocab>, t: int32,
      buf: mutable_ptr<byte>, buf_len: int32,
      lstrip: int32, special: bool): int32

  export func llama_batch_get_one(
      tokens: mutable_ptr<int32>, n: int32): llama_batch

  export func llama_decode(
      c: mutable_ptr<llama_context>, b: llama_batch): int32

  export func llama_sampler_sample(
      s: mutable_ptr<llama_sampler>,
      c: mutable_ptr<llama_context>,
      idx: int32): int32

  export func llama_sampler_accept(
      s: mutable_ptr<llama_sampler>, t: int32): void

  export func llama_sampler_free(s: mutable_ptr<llama_sampler>): void
}