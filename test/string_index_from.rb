# Regression: `String#index(sub, start)` 2-arg form.
# Pre-fix the codegen ignored `start` and re-emitted the 1-arg
# call, so a "find next dot after position N" walk all returned
# the first match.
#
# Updated for #532: `String#index` now returns nil (not -1) for
# not-found, matching CRuby. `puts nil.to_s` prints an empty
# line; the walk-all-dots loop checks `pos.nil?` instead of
# `pos < 0`.

s = "a.b.c.d"

# 1-arg form -- baseline.
puts s.index(".").to_s          # 1

# 2-arg form -- the fix.
puts s.index(".", 0).to_s       # 1   (no skip, finds the same first dot)
puts s.index(".", 1).to_s       # 1   (start at the dot itself, finds it)
puts s.index(".", 2).to_s       # 3   (skip past the first dot, find the second)
puts s.index(".", 4).to_s       # 5
puts s.index(".", 6).to_s       # "" (nil.to_s; CRuby would print blank)

# Negative start counts from end.
puts s.index(".", -1).to_s      # "" (not found, nil.to_s)
puts s.index(".", -2).to_s      # 5    (last dot)
puts s.index(".", -100).to_s    # 1    (clamps to 0)

# Out-of-range positive start.
puts s.index(".", 100).to_s     # "" (not found, nil.to_s)

# Multibyte: codepoint indexing, not byte indexing.
m = "α.β.γ"
puts m.index(".").to_s          # 1   (one cp before the first dot)
puts m.index(".", 2).to_s       # 3   (after the first dot)

# Walk-all-dots loop -- the JWT use case that surfaced this bug.
# Idiomatic post-#532: `break if pos.nil?` instead of `pos < 0`.
t = "header.payload.sig"
i = 0
positions = ""
while true
  pos = t.index(".", i)
  if pos.nil?
    break
  end
  positions = positions + pos.to_s + ","
  i = pos.to_i + 1
end
puts positions                  # 6,14,
