class NameTag
  attr_reader :text

  def initialize(text)
    @text = text
  end
end

class Payload
end

class Wrapper
  attr_reader :tag, :payload

  def initialize(tag, payload)
    @tag = tag
    @payload = payload
  end
end

wrappers = []
i = 0
while i < 2000
  wrappers << Wrapper.new(NameTag.new("label" + i.to_s), Payload.new)
  i = i + 1
end

junk = []
i = 0
while i < 5000
  junk << "garbage" + i.to_s
  i = i + 1
end

puts wrappers[1999].tag.text
