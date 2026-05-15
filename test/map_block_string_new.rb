# #522. Sibling to #519. The literal-array path `[String.new]` was
# fixed in #519 to infer as `mutable_str_ptr_array` (a sp_PtrArray
# of sp_String*). The `.map { String.new }` path didn't share the
# inference — block-return type `mutable_str` was missing from the
# map-result type cascade, so the accumulator stayed at the
# default int_array shape and the push failed C compilation with
# `sp_IntArray_push(arr, sp_String_new(""))`.
#
# Fix: add a `mutable_str` arm in both the analyzer
# (infer_call_type's map branch -> mutable_str_ptr_array) and the
# codegen (int_array recv branch -> sp_PtrArray accumulator with
# `(void *)val` push).

xs = [1, 2, 3]

# Block returns String.new directly.
result = xs.map { |x| String.new }
puts result.length

# Block returns a local widened to mutable_str.
result2 = xs.map { |x| s = String.new; s << "v"; s }
puts result2.length
