class Counter
  def initialize
    @n = 0
    @fiber = Fiber.new do
      @n += 10
      Fiber.yield
      @n += 100
      Fiber.yield
      @n += 1000
    end
  end

  def step
    @fiber.resume
    @n
  end
end

c = Counter.new
puts c.step
puts c.step
puts c.step
