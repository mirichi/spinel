class NameTag
  attr_reader :present, :text

  def initialize(present, text)
    @present = present
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

  def self.for_tag(tag)
    junk = []
    i = 0
    while i < 50
      junk << "junk" + i.to_s
      i = i + 1
    end

    Wrapper.new(tag, Payload.new)
  end
end

wrapper = nil
i = 0
while i < 2000
  wrapper = Wrapper.for_tag(NameTag.new(1, "label" + i.to_s))
  i = i + 1
end

puts wrapper.tag.text
