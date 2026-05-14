# #486. Class method with a kwarg `set_cookies: {}` whose
# param is body-widened (via other call sites passing a
# sym-keyed hash) to sp_SymStrHash *. A bare call site that
# omits the kwarg synthesized the default at the call site as
# the generic sp_StrIntHash_new(), tripping
# -Wincompatible-pointer-types because the callee expects
# sp_SymStrHash *. Fix: the kwarg-default emit at the class-
# method dispatch site routes through empty_hash_coerce so an
# empty `{}` literal default takes on the param's declared
# hash variant.

class W
  def self.write(io, status, set_cookies: {})
    n = 0
    set_cookies.each do |name, val|
      n = n + 1
    end
    n
  end
end

class Use
  def self.kick
    cookies = { flash_notice: "Hi" }
    W.write(1, 200, set_cookies: cookies)
  end
end

puts W.write(1, 404).to_s
