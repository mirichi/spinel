# Issue #871: NilClass coercion methods. v1 covers to_i / to_f /
# to_a. to_c, to_r, to_h deferred (Complex, Rational unsupported;
# typed-Hash empty needs element-type judgement).
puts nil.to_i
puts nil.to_f
puts nil.to_a.inspect
