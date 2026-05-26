# Issue #903: String#codepoints returns int_array of UTF-8
# codepoints (not bytes).
puts "hello".codepoints.inspect
puts "あ".codepoints.inspect
puts "".codepoints.inspect
