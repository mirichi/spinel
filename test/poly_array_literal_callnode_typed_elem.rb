# `[A, B]` outer literal where A and B are non-ArrayNode expressions
# returning a typed `<X>_ptr_array` (e.g. `(0..N).map { ... }`).
# Without the fix, compile_array_literal's poly_array branch hits
# `box_value_to_poly(et, val)` for the CallNode element, which lowers
# to `sp_box_ptr_array(val)` — cls_id PTR_ARRAY only, the inner
# element type is erased. Subsequent `arr[b][i][j]` reads dispatch
# through the PTR_ARRAY arm at level 1, which boxes the next-level
# element as `sp_box_obj(p, 0)` (cls_id 0, "unknown obj"), and the
# level-2 dispatch can't match any cls_id arm — every leaf read
# returns 0.
#
# With the fix, the runtime conversion loop iterates the typed
# PtrArray and pushes each inner with `sp_box_<inner-type>` (e.g.
# `sp_box_int_array(...)` for an IntArray element), so the cls_id
# chain stays tagged through every level.

class C
  def initialize
    @a = [(0..3).map { |i| [i * 10, i * 10 + 1, i * 10 + 2] },
          (0..3).map { |i| [i * 100, i * 100 + 1, i * 100 + 2] }]
  end
  def get(b, i, j); @a[b][i][j]; end
  def out_len; @a.length; end
  def mid_len(b); @a[b].length; end
  def in_len(b, i); @a[b][i].length; end
end

c = C.new
puts c.out_len           # 2
puts c.mid_len(0)        # 4
puts c.in_len(0, 0)      # 3
puts c.get(0, 0, 0)      # 0
puts c.get(0, 1, 1)      # 11
puts c.get(0, 3, 2)      # 32
puts c.get(1, 0, 0)      # 0
puts c.get(1, 2, 1)      # 201
puts c.get(1, 3, 2)      # 302
