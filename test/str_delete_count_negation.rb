# String#delete and String#count with ^-negated charset
# ^ at the start inverts the charset meaning.

# delete: normal charset
puts "hello".delete("l").inspect
# delete: negated charset
puts "hello".delete("^l").inspect

# count: normal charset
puts "hello".count("l")
# count: negated charset
puts "hello".count("^l")
