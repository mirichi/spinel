class Stepper
  def initialize
    @count = 0
    @fiber = Fiber.new { main_loop }
  end

  def step
    @fiber.resume
    @count
  end

  def main_loop
    while @count < 5
      tick
      tick
      Fiber.yield
    end
  end

  def tick
    @count += 1
  end
end

s = Stepper.new
puts s.step
puts s.step
puts s.step
