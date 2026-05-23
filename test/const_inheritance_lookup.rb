# Issue #668: constants defined in a parent class should be visible to
# instance methods of the child class via the inheritance chain. Pre-fix
# the bare `CONST` lookup walked only the lexical-scope chain (Child,
# then trim) and the include chain — never the @cls_parents superclass
# chain — so methods defined on Child couldn't see Parent's CONST and
# the codegen emitted a "uninitialized constant" warning + 0.

class Parent
  CONST = "parent"
end

class Child < Parent
  def get_const
    CONST
  end
end

puts Child.new.get_const

# Two-level chain (Grandchild -> Child -> Parent) so the recursive
# parent walker is exercised.
class Grandchild < Child
  def get_again
    CONST
  end
end

puts Grandchild.new.get_again
