# #532. `String#index` / `String#rindex` previously returned
# mrb_int with -1 as the not-found sentinel. The CRuby idiom
#
#   pos = body.index('"content"', i)
#   break if pos.nil?
#
# silently broke because `pos.nil?` on a plain-int local is
# always false (per #521's strict `int == nil`), so the loop
# never exits and i wanders past the buffer.
#
# Fix: widen `String#index` / `String#rindex` to return sp_RbVal
# (boxed nil for the -1 sentinel, boxed int for found). The
# CRuby semantics now work end-to-end:
# - `pos.nil?` / `pos == nil` / `pos != nil` via tag check
# - `pos.inspect` via sp_poly_inspect (prints "nil" or the int)
# - `while pos = s.index(...)` truthiness (boxed nil is falsy)
#
# Cost: downstream call sites that consume `pos` as a raw int
# need to unbox. compile_expr_as_int / compile_arg0_as_int in
# the codegen handle the int-expecting C helper signatures
# (sp_str_sub_range etc.).

s = "hello world"

# Found and not-found inspect (formerly "6" / "-1"; now "6" / "nil").
puts s.index("world").inspect    # 6
puts s.index("xyz").inspect      # nil
puts s.index("hello").inspect    # 0   (real index 0, not nil)

# CRuby's nil-lens idiom now works without rewrites.
pos = s.index("xyz")
puts pos.nil?                    # true
puts (pos == nil)                # true
puts (pos != nil)                # false

pos = s.index("hello")
puts pos.nil?                    # false (real index 0 is NOT nil)
puts (pos != nil)                # true

# rindex inherits the same shape.
puts "abcdabcd".rindex("c").inspect    # 6
puts "abcdabcd".rindex("z").inspect    # nil

# Walk-all idiom from the issue's GPT-2 BPE example.
body = "header.payload.sig"
i = 0
positions = ""
while true
  pos = body.index(".", i)
  break if pos.nil?
  positions = positions + pos.to_s + ","
  i = pos.to_i + 1
end
puts positions                   # 6,14,
