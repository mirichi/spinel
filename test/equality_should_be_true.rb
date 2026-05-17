# #555 (gurgeous/Adam Doppelt). A corpus of `should be true`
# expressions that compiled to false in spinel pre-fix.
# Each line is an independent equality predicate; CRuby
# returns true for all twelve, and after the followup
# commits spinel matches on 10 of 12 (cases 1-6, 8-10, 12).
# Cases 7 (Array#dig over heterogeneous poly_array of hashes)
# and 11 (`=~` pos+1 sentinel vs CRuby's 0-indexed semantics)
# remain.

p ({} == {})                                     # 01
p ({a: 1} == {a: 1})                             # 02
p ({:a= => 1} == {:"a=" => 1})                   # 03
p ({:a! => 1} == {:"a!" => 1})                   # 04
p ({:a? => 1} == {:"a?" => 1})                   # 05
a = [1] ; a.shift ; a << :foo ; p (a == [:foo])  # 06
a2 = [1, 2, 3, 4, 5] ; p ((a2[2, 3] = 10) == 10) # 08
p ("hello".chars == ['h', 'e', 'l', 'l', 'o'])   # 09
p "abc\r\n".chomp(nil) == "abc\r\n"              # 10
p ((1..).send(:include?, 2.4) == true)           # 12
