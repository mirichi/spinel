# Spinel adopts `# frozen_string_literal: true` semantics
# globally — every string literal is frozen, mutation requires
# a heap-allocated buffer (`.dup`, `+`, etc.). setbyte on a
# literal raises FrozenError with the same message CRuby uses
# when the pragma is in effect.

# Direct literal recv.
begin
  "abc".setbyte(0, 67)
  puts "no raise (literal)"
rescue FrozenError => e
  puts "literal: " + e.message
end

# LV pointing at a literal.
s = "abc"
begin
  s.setbyte(0, 67)
  puts "no raise (lv-literal): " + s
rescue FrozenError => e
  puts "lv-literal: " + e.message
end

# Dup'd heap string mutates cleanly.
s2 = "abc".dup
s2.setbyte(0, 67)
puts s2   # Cbc

# Concatenation produces a heap buffer too.
s3 = "x" + "y"
s3.setbyte(0, 90)
puts s3   # Zy

# Heap aliasing: setbyte on shared object affects both refs.
s4 = "ab".dup
s5 = s4
s4.setbyte(0, 67)
puts s5   # Cb (shared heap, both see the mutation)

# ivar holding a heap string mutates through method dispatch.
class Buf
  attr_reader :s
  def initialize
    @s = "abc".dup
  end
  def hit
    @s.setbyte(0, 67)
  end
end
b = Buf.new
b.hit
puts b.s   # Cbc
