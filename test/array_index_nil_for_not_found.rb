# `Array#index(x)` / `#find_index(x)` / `#rindex(x)` return
# Integer | nil in CRuby (nil when not found). spinel previously
# returned the raw -1 sentinel from `sp_*Array_index`, which
# diverged from CRuby's nil for the not-found case.
#
# spinel positions itself as a Ruby SUBSET, so documented Ruby
# APIs must match CRuby behavior. The fix: codegen now routes
# Array#index family through `sp_*Array_index_poly` wrappers
# that box nil for not-found / box int for found. The type
# inference returns "poly" for the call result so `.nil?` /
# `== nil` checks dispatch through the standard poly-tag path.
#
# The raw `_index` helpers (returning -1) stay for any internal
# caller that needs the sentinel.

# Int arrays
ints = [10, 20, 30, 40]
puts ints.index(20).inspect       # 1
puts ints.index(999).inspect      # nil
puts ints.index(999).nil?         # true
puts ints.index(20).nil?          # false
puts ints.find_index(30).inspect  # 2

# String arrays
strs = ["alpha", "beta", "gamma"]
puts strs.index("beta").inspect   # 1
puts strs.index("zeta").inspect   # nil
puts strs.rindex("alpha").inspect # 0
puts strs.rindex("zeta").inspect  # nil
