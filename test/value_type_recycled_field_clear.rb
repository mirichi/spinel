class NameTag
  attr_reader :text

  def initialize(text)
    @text = text
  end
end

class Holder
  attr_reader :tag, :junk

  def initialize(tag)
    @junk = []
    @tag = tag
  end
end

i = 0
while i < 3000
  Holder.new(NameTag.new("old" + i.to_s))
  i = i + 1
end

junk = []
i = 0
while i < 5000
  junk << "garbage" + i.to_s
  i = i + 1
end

holder = nil
i = 0
while i < 3000
  holder = Holder.new(NameTag.new("new" + i.to_s))
  i = i + 1
end

puts holder.tag.text
