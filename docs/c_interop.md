## *void / opaque pointer params (v2)

`*void` and `*const void` parameters are treated as raw pointer values — the
compiler does not auto-dereference them on read. Only concrete typed pointers
(`*int32`, `*MyStruct`, etc.) receive the transparent by-ref load/store
treatment. This distinction matters for C interop functions that accept or
return opaque handles.