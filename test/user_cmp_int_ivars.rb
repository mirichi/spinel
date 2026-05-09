# Issue #399: a user-defined `def <=>(other)` whose body calls
# `<=>` on Integer ivars (`@n <=> other.n`) lowered to a recursive
# call to the user's own `<=>` method (passing the int receivers
# cast to `sp_V *`). Type error + would-be infinite recursion.
#
# Fix: compile_int_method_expr now has a `<=>` arm that emits the
# standard 3-way compare for int-vs-int (and int-vs-float). Plus
# `<=>` is added to is_primitive_shared_method so the int-recv
# fallback at compile_call_expr's tail doesn't pick a user class.

class V
  attr_reader :n
  def initialize(n)
    @n = n
  end

  def <=>(other)
    @n <=> other.n
  end
end

a = V.new(1)
b = V.new(2)
c = V.new(2)

puts (a <=> b).to_s   # -1
puts (b <=> a).to_s   # 1
puts (b <=> c).to_s   # 0

# Standalone `==` falls back to identity, which doesn't help here;
# the issue is just the recursion inside `<=>`. Spinel's Comparable
# include path is a separate feature.
