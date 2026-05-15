# #516. When a parent-class instance method calls another method
# via implicit-self dispatch and a subclass overrides that
# method, the parent's typed call-site arg didn't propagate to
# the subclass override's parameter. The override's param
# stayed at the int default and the body's dispatch on it
# failed.
#
# Fix: in scan_cls_method_calls' implicit-self CallNode arm,
# after widening the same-class method's ptypes from the
# arg_ids, also walk @cls_names for descendants that
# direct-override the same method name and widen their
# ptypes from the same arg_ids. The descendant's C signature
# now agrees with the cls_id-switch dispatch that the imeth
# emit later builds.

class Base
  def reload(row)
    consume(row)
  end
  def consume(_row)
    "base default"
  end
end

class Sub < Base
  def consume(row)
    row["id"]
  end
end

puts Sub.new.reload({"id" => "42"})

# Three-level chain: param flows through two override layers.
class Parent
  def kick(payload)
    handle(payload)
  end
  def handle(_p)
    "parent"
  end
end

class Mid < Parent
  def handle(p)
    "mid:" + p[:name]
  end
end

class Leaf < Mid
  def handle(p)
    "leaf:" + p[:name]
  end
end

puts Mid.new.kick({name: "m"})
puts Leaf.new.kick({name: "l"})
