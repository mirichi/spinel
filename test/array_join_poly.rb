# Array#join on a mixed-element (poly) array: each element is to_s'd and
# joined with the separator. Homogeneous int_array/str_array have their
# own join; these literals are heterogeneous so they use poly storage.
puts [1, "x", :y].join(",")
puts [1, "x", :y].join
puts [10, "y"].join("-")
puts "done"
