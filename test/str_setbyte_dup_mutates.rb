# `String#setbyte` on a heap-allocated string mutates in place.
# Spinel adopts `# frozen_string_literal: true` semantics
# globally: string literals are frozen (rodata-resident), so a
# setbyte on a literal raises FrozenError; setbyte on a heap
# buffer (from .dup, +, *, gsub, etc.) mutates as usual.
#
# This test pins the heap-mutate path. Literal -> FrozenError is
# covered by test/str_setbyte_frozen_literal.

# Dup'd string: setbyte mutates.
s = "ab".dup
s.setbyte(0, 67)  # 'C'
s.setbyte(1, 68)  # 'D'
puts s   # CD

# String#+ produces a fresh heap buffer too.
s2 = "x" + "y"
s2.setbyte(0, 90)  # 'Z'
puts s2  # Zy
