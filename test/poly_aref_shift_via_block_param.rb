# `<poly>[idx]` flowing into an int operator (`>>` / `<<` / ...)
# inside an `.each {|a| ... }` block must unbox the sp_RbVal result
# of `a[idx]` before the C operator.
#
# `entries` here is one half of a destructured 2-tuple from a
# nested-ivar chain (`@store[bank][idx]`), which widens it to poly.
# The block param `a` is then poly (not poly_array), so `a[2]`
# emits via compile_poly_method_call's runtime tag-check → sp_RbVal.
# Pre-fix, the analyze cache for `a[2]` sat at "int" (one observed
# elem kind), so `compile_arg0_as_int` for `data >> a[2]` skipped
# the unbox and emitted `lv_data >> _t.sp_RbVal` into the C —
# `invalid operands to binary >>`. The fix in infer_type matches
# the actual emit so the unbox lands.

class C
  def initialize
    # @store[bank][idx] is a 2-tuple: (names, entries).  Each entry
    # in `entries` is a [tag, payload, shift] triple; the
    # heterogeneous element shape forces poly typing through the
    # destructure.
    @store = [[ [[1], [[10, [0, 1, 2], 4], [20, [3, 4, 5], 6]]] ]]
  end

  def run(bank, idx, data)
    _names, entries = @store[bank][idx]
    entries.each do |a|
      shifted = data >> a[2]
      puts shifted & 3
    end
  end
end

C.new.run(0, 0, 0xff)
