# `String#setbyte` mutates the receiver in place. Spinel strings
# are `const char *` so the codegen path used to either crash on
# literals (pre-#504) or silently no-op every call (post-#504).
# The runtime helper `sp_str_setbyte` now gates the write on the
# marker byte at s[-1]:
#
#   0xfe / 0xfc -> sp_str_alloc heap (writable)
#   0xfd        -> sp_String wrapper buffer (writable)
#   0xff        -> rodata literal (no-op — spinel intentionally
#                  diverges from MRI here: MRI's unfrozen literals
#                  are mutable, spinel keeps literals in rodata)
#   other       -> FFI / unknown, no-op (conservative)
#
# Test: a `.dup`'d string lives on the heap (0xfe marker) and
# setbyte mutates it in place. bm_ruby_xor exercises the same
# shape over 16 000 strings × 16 bytes. The literal-LV no-op case
# is covered by test/str_method_nil_arg_no_segv.

# Dup'd string: setbyte mutates.
s = "ab".dup
s.setbyte(0, 67)  # 'C'
s.setbyte(1, 68)  # 'D'
puts s   # CD

# String#+ produces a fresh heap buffer too.
s2 = "x" + "y"
s2.setbyte(0, 90)  # 'Z'
puts s2  # Zy
