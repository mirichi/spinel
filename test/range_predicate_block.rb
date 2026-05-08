# `(a..b).any?/all?/none?/one? { |i| ... }` — the array-shape
# predicate emitter already handles ranges via emit_iter_open;
# the range method dispatcher just needs to route to it. Without
# the route, the call falls through to the unresolved-call
# warning and returns literal 0.
#
# Surfaced via optcarrot's PPU `(0..3).all? {|i| @nmt_ref[i] == idxs[i] }`.

# all? — every element matches
puts (0..5).all? {|i| i >= 0 }      # true
puts (0..5).all? {|i| i < 3 }       # false
puts (0..3).all? {|i| (0..3).cover?(i) }  # true

# any? — at least one matches
puts (0..5).any? {|i| i == 3 }      # true
puts (0..5).any? {|i| i > 100 }     # false

# none? — no element matches
puts (0..5).none? {|i| i > 100 }    # true
puts (0..5).none? {|i| i == 3 }     # false

# one? — exactly one matches
puts (0..5).one? {|i| i == 3 }      # true
puts (0..5).one? {|i| i >= 4 }      # false (matches 4 and 5)
puts (0..5).one? {|i| i > 100 }     # false (matches none)
