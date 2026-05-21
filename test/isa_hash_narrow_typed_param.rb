# `is_a?(Hash)`-narrowed poly value passed to a typed-Hash param
# slot should unbox via `(sp_<Variant> *).v.p`, matching the
# obj-narrow arm at #448. Pre-fix compile_typed_call_args's
# dispatch only routed `poly`/`string`/array params (and
# obj-typed params when arg was poly) through
# compile_expr_for_expected_type; hash-typed params fell through
# to `compile_expr` and emitted the bare sp_RbVal, failing the
# C compile with "passing 'sp_RbVal' to parameter of incompatible
# type 'sp_StrStrHash *'". Issue #631.

class Bag
  def render(hash)
    hash["k"]
  end

  def visit(table)
    seed = { "k" => "v" }
    render(seed)

    val = table["inner"]
    if val.is_a?(Hash)
      render(val)
    else
      "default"
    end
  end
end

b = Bag.new
puts b.visit({ "inner" => { "k" => "tokyo" } })
