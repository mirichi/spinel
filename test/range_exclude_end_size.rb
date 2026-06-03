# Non-literal ranges: passing through a method parameter defeats
# compile-time constant-folding, so `exclude_end?`/`size`/`count`/
# `length` must read the runtime `excl` flag off the sp_Range struct.
def report(r)
  puts r.exclude_end?
  puts r.size
  puts r.count
  puts r.length
end

report(1...5)
report(1..5)

# Literal ranges: compile-time receiver -- regression guard.
puts (1...5).exclude_end?
puts (1..5).exclude_end?
puts (1...5).size
puts (1..5).size
puts (1...5).count
puts (1..5).count
puts (0...10).size
puts (0..10).size
puts (1...5).length
puts (1..5).length
