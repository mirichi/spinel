# `attr_accessor :foo` with no `initialize`-time assignment must
# read as nil before any write. Pre-fix spinel registered the
# slot as the "int" placeholder, so the unset read returned 0
# (the type's zero) and downstream `"[#{a.counter}]"` rendered
# `[0]` instead of MRI's `[]`. Issue #634 shape B.
#
# The widening fires only when (a) the ivar is exposed via
# attr_reader / attr_accessor, (b) no method body assigns it,
# and (c) no writer call site has been observed during the
# iterative inference loop. A class whose `reset` method writes
# the slot (optcarrot's APU oscillators) keeps the typed slot;
# `b.counter = 0` on a sibling instance also keeps the typed
# slot, but the uninitialized `a.counter` read on a fresh
# `A.new` still returns nil through the per-instance poly
# storage.

class A
  attr_accessor :counter
end

a = A.new
puts "[#{a.counter}]"

b = A.new
b.counter = 0
puts "[#{b.counter}]"

# Shape with attr_reader-only (no writer at all).
class Box
  attr_reader :tag
end

box = Box.new
puts "tag=[#{box.tag}]"
