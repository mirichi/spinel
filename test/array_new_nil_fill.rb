# `Array.new(n, nil)` -- the fill value is the nil singleton, so
# MRI fills each slot with `nil` and `.inspect` prints
# "[nil, nil, ...]". Spinel previously lowered the call to an
# int_array filled with the C default (0), and inspect printed
# "[0, 0, 0]". Lowering must produce a sp_PolyArray so the slot
# can carry the nil tag and `.inspect` / `[i].nil?` / etc. see
# the actual nil.

ary = Array.new(3, nil)
puts ary.inspect
puts ary[0].nil?
puts ary[1].nil?
puts ary[2].nil?
puts ary.length
