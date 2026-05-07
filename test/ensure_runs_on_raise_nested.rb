# Nested `begin..ensure..end` with raise — both ensures must run
# (inner first, then outer) before the exception reaches the
# enclosing rescue.

class T
  def initialize
    @inner = "no"
    @outer = "no"
    @log = ""
  end

  def f
    begin
      begin
        raise "inner-boom"
      ensure
        @inner = "yes"
        @log = @log + "i"
      end
    ensure
      @outer = "yes"
      @log = @log + "o"
    end
  end

  def report
    begin
      f
    rescue => e
      puts e
    end
    puts @inner
    puts @outer
    puts @log
  end
end

T.new.report
