class T
  def initialize
    @ready = false
    @count = 0
  end

  def maybe_inc
    @ready &&= step
  end

  def arm
    @ready = true
  end

  def step
    @count += 1
    true
  end

  def state
    "ready=#{@ready} count=#{@count}"
  end
end

t = T.new
puts t.state
t.maybe_inc
puts t.state
t.arm
puts t.state
t.maybe_inc
puts t.state
t.maybe_inc
puts t.state
