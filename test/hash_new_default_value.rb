# `Hash.new(default_value)` per-instance default support.
#
# Each hash variant struct (StrIntHash / StrStrHash / IntStrHash /
# SymIntHash / SymStrHash / StrPolyHash / SymPolyHash) gains a
# `default_v` field. `_new` initializes it to the variant's
# sentinel zero (so legacy `{}` literals unchanged); `_new_with_default`
# is a new constructor that sets the field. `_get` returns
# `default_v` on miss; `_dup` / `_merge` propagate (merge inherits
# the LEFT receiver's default per CRuby).
#
# Codegen routes `Hash.new(N)` through `_new_with_default` and
# adds `Hash#default` / `Hash#default=` accessor arms to each
# variant. The analyzer's `infer_call_type` arm picks the right
# variant from the default's type (string → str_str_hash, int
# / nil / bool → str_int_hash) and types `h.default` as the
# value-slot type so `puts h.default` dispatches correctly.
#
# Block form `Hash.new { |h, k| ... }` (proc default) remains
# deferred -- separate feature.
#
# Issue #600 puzzle 2.

# Int default
h = Hash.new(5)
puts h[:a]              # 5
puts h["x"]             # 5
puts h.length           # 0
puts h.key?(:a)         # false
puts h.default          # 5

# Modify default; existing key unaffected
h.default = 99
puts h["missing"]       # 99
h["b"] = 10
puts h["b"]             # 10
puts h["c"]             # 99

# String default
s = Hash.new("none")
puts s["x"]             # none
puts s.default          # none

# dup propagates default
h2 = Hash.new(42)
h2["a"] = 1
d = h2.dup
puts d.default          # 42
puts d["never_set"]     # 42
puts d.length           # 1
puts d["a"]             # 1

# merge inherits left default
m = h2.merge({"x" => 100})
puts m.default          # 42
puts m["not_there"]     # 42

# Hash.new(0) -- pre-existing lrama_features shape, default ==
# sentinel, behaviour unchanged.
counter = Hash.new(0)
counter["x"] = counter["x"] + 1
puts counter["x"]       # 1
puts counter["z"]       # 0
