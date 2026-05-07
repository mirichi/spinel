# When the body of a `begin..ensure..end` raises, the ensure
# clause must still run before the exception keeps propagating.
# Previously the generated C had no setjmp around the body, so
# raise unwound past the ensure entirely.

class C
  def initialize
    @cleanup = "no"
    @before_raise = 0
  end

  def f
    begin
      @before_raise = 1
      raise "boom"
    ensure
      @cleanup = "yes"
    end
  end

  def report
    begin
      f
    rescue => e
      puts e
    end
    puts @before_raise
    puts @cleanup
  end
end

C.new.report
