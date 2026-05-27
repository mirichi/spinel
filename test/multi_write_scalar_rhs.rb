# Scalar int RHS to multi-assign: `a, b = 1` previously emitted
# `sp_IntArray *_t = 1LL;` which failed to compile. CRuby treats
# the scalar as `[scalar]` so the first slot gets it; the rest are
# nil in CRuby but land as the typed slot's default (0) here.
a, b = 1
puts a
puts b

e, f, g = 42
puts e
puts f
puts g
