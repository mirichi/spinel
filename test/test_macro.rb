module MyModule
  def_macro :set_pixel, "draw_pixel({0}, {1}, {2})"

  inline_c 'int draw_pixel(int x, int y, int c) { printf("pixel: %d,%d = %X\n", x, y, c); return 0; }'

  def self.test(x, y)
    c = 0xFFFFFF
    # Call the macro
    set_pixel(x, y, c)
  end
end

MyModule.test(10, 20)
