# Issue #429. Two unrelated classes each defining `def get(k)`
# with different return types caused the analyzer's int-recv
# cross-class widening to pick the first match -- so a local
# `r = c.get("/foo")` where c is statically obj_IntClient ended
# up declared `const char *` (from StrBag#get's String return),
# crashing the C compile when sp_IntClient_get returned an
# sp_IntBag *.
#
# Fix: scan_locals' first pass calls infer_type before the
# scope decls land, so `c`'s var-type is "" / "int" at that
# point. infer_recv_method_type's int-recv arm enumerates
# every user class with `mname` and picks the first non-int
# return. The fix bails out of that path when (a) the recv is
# a LocalVariableReadNode whose var-type isn't pinned yet, and
# (b) the candidate classes disagree on the return type --
# leaving a later iteration of the iterative loop to pick the
# right one via the is_obj_type arm once `c`'s declaration
# has propagated.
#
# Coverage: the canonical "two classes, same imeth name,
# different return types, statically-typed call sites for
# each" shape from Ori's repro.

class StrBag
  def initialize
    @h = {"a" => "b"}
    @h.delete("a")
    @h["x"] = "got-x"
  end
  def get(k)
    @h[k]
  end
end

class IntBag
  attr_accessor :status
  def initialize
    @status = 42
  end
end

class IntClient
  def get(path)
    out = IntBag.new
    out.status = path.length
    out
  end
end

s = StrBag.new
puts s.get("x")

c = IntClient.new
r = c.get("/foo")
puts r.status
