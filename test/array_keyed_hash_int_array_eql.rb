# Array-keyed Hash. `entries[[a, b]] ||= ...` was broken because
# spinel's PolyPolyHash defaulted to pointer-identity comparison
# for SP_TAG_OBJ keys — every fresh `[a, b]` literal allocated a
# new IntArray, so identical-content keys never matched and the
# `||=` never deduped. The cache grew unboundedly and reads with
# a fresh `[a, b]` returned nil.
#
# Fix: extend the codegen-emitted sp_obj_hash_hook /
# sp_obj_eql_hook to handle SP_BUILTIN_INT_ARRAY with element-wise
# content hash + comparison. Two IntArray instances with the same
# elements now hash and eql? identically — array-keyed Hash
# behaves like CRuby's `Hash` with the [a,b]-style key idiom.

entries = {}
entries[[1, 2]] = "a"
entries[[3, 4]] = "b"
entries[[1, 2]] ||= "z"   # already set, no overwrite
puts entries[[1, 2]]      # "a"
puts entries[[3, 4]]      # "b"
puts entries.length       # 2

# Heterogeneous keys still work — int / IntArray / string mixed.
mixed = {}
mixed[42] = "int-key"
mixed[[5, 6, 7]] = "arr-key"
mixed[[5, 6, 7]] ||= "no-overwrite"
puts mixed[42]            # int-key
puts mixed[[5, 6, 7]]     # arr-key
puts mixed.length         # 2
