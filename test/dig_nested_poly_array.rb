# Array#dig walks through nested poly_array elements with int keys.
# Pre-fix emit_dig_step's int-key branch only emitted an arm for
# SP_BUILTIN_INT_STR_HASH; every other receiver kind collapsed the
# accumulator to nil at the next step, so a nested poly_array
# dig surfaced nil instead of the leaf value. Issue #619 puzzle 6.

p [[1, [2, "3"]]].dig(0, 1, 1) == "3"   # true (string leaf)
p [[1, [2, "3"]]].dig(0, 0) == 1        # true (int leaf via box_int)
p [[1, [2, "3"]]].dig(0, 1, 0) == 2     # true
p [[1, [2, "3"]]].dig(0, 1, 5).nil?     # true (OOB at the last step)
