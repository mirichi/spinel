# Issue #642. A call site missing a required positional arg used
# to compile clean with no warning, silently padding the slot with
# `0` (or sp_box_nil for poly). Result: the binary ran with
# garbage in the missing slot, producing real-world bugs like the
# tep#13 "looks-like-200-OK" failure.
#
# After fix: a one-shot stderr warning per (callee, missing slot)
# fires at compile time. The call still emits `0` so the codegen
# completes (hard error would tear up partially-implemented
# patterns), but the warning surfaces the mistake.
#
# This test only pins runtime behaviour. The compile-time stderr
# warning is checked manually; assert the call still runs (since
# we keep emitting 0 for compat).

module M
  def self.run!(a, b, c, d)
    puts "a=#{a} b=#{b} c=#{c} d=#{d}"
  end
end

M.run!(1, 2, false)        # missing `d`; d emits as 0 (and warning fires at compile)
M.run!(10, 20, true, 30)   # all args supplied
