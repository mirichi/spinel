# Issue #850: String#gsub with empty pattern inserts the
# replacement between every character (and at the start/end).
# Pre-fix, empty pattern was a no-op.
puts "hello".gsub("", "x")
puts "abc".gsub("", "-")
