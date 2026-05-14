# #487. Top-level begin/rescue sets @needs_setjmp = 1, which emits
# every main() local as `volatile T *`. Passing such a local to a
# function expecting plain `T *` triggers gcc's
# -Wdiscarded-qualifiers / clang's
# -Wincompatible-pointer-types-discards-qualifiers. The program
# still runs correctly (volatile is strictly stronger than what the
# callee asks for); the fix casts away the qualifier at the call
# site so clean builds under -Wall stay green.

class M
  def self.read(env)
    env["k"]
  end
end

env = { "k" => "v" }
begin
  puts M.read(env)
rescue
  puts "rescued"
end
