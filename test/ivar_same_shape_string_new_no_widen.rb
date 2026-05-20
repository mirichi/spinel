# Two `String.new` writes to the same ivar should keep the slot at
# `sp_String *`, not widen to `sp_RbVal`. Pre-fix scan_ivars used
# `infer_ivar_init_type` which returned `obj_String` for the first
# write; later writer-scan saw `mutable_str` via `infer_type` for the
# second; update_ivar_type took the disagreement as a real conflict
# and widened to poly. Issue #629.

class T
  def initialize
    @body = String.new
  end

  def reset
    @body = String.new
  end

  def append(s)
    @body << s
  end

  def body
    @body
  end
end

t = T.new
t.append("hello")
puts t.body
t.reset
t.append("world")
puts t.body
