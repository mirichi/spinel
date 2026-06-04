# Hash#fetch on an int->int specialized hash: plain lookup and the 2-arg
# default form (the int->int variant previously had #[] but not #fetch).
h = { 1 => 10, 2 => 20 }
puts h.fetch(1)
puts h.fetch(2)
puts h.fetch(9, -1)
puts h.fetch(0, 42)
puts "done"
