# `h = {}; h[parts[0]] = v` where `parts` comes from a `split` result
# (or any expression that returns str_array). Pre-fix the first-pass
# scan_locals saw `parts` undeclared and inferred `parts[0]` as int,
# then `promote_empty_hash_for("int", "int")` widened `h` to
# `poly_poly_hash` — destructive: a later pass that correctly
# resolves the key as string couldn't downgrade `h` back.
#
# Now kt="int" with vt="int"/"bool"/"nil" returns "" (defer) so the
# second pass with the key resolved produces str_int_hash.
#
# Sibling check: kt="int" with vt="string" still gives int_str_hash
# (the legitimate int-keyed-string-valued case stays intact).

def build_str_keyed(s)
  parts = s.split("/")
  h = {}
  h[parts[0]] = 1
  h
end

def build_int_keyed
  h = {}
  h[200] = "OK"
  h[404] = "NotFound"
  h
end

h1 = build_str_keyed("a/b")
puts h1["a"]            # 1

h2 = build_int_keyed
puts h2[200]            # OK
puts h2[404]            # NotFound
