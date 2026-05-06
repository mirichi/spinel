# `<poly>.each` runtime dispatch on cls_id. The compile_each_block
# handler previously bailed when the receiver type was `poly` (no
# matching `if rt == "..."` branch), so a method body that ends in
# `iterable.each do |a| ... end` over a poly slot silently dropped
# the iteration.
#
# Repro: an ivar `@store` widened to poly via two distinct array
# shapes (an int_array and a poly_array) is iterated via `.each`.
# Spinel previously emitted no loop at all — the body never ran.
# The block param `a` is delivered as sp_RbVal (the widest fit
# across the cls_id arms).

class C
  def store_int_array
    @store = [10, 20, 30]
  end
  def store_poly_array
    @store = [nil] * 3
    @store[0] = "a"
    @store[1] = "b"
    @store[2] = "c"
  end
  def visit
    @store.each do |x|
      puts x.to_s
    end
  end
end

c = C.new
c.store_int_array
c.visit
puts "---"
c.store_poly_array
c.visit
