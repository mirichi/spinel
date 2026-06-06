module MyFFI
  inline_c '
    typedef struct {
      int x;
      int y;
    } Point;

    Point* create_point(int x, int y) {
      Point *p = (Point*)malloc(sizeof(Point));
      p->x = x;
      p->y = y;
      return p;
    }
  '

  # Cast the pointer to mrb_int so it can be assigned to a Spinel int variable
  def_macro :create_point, "((mrb_int)create_point({0}, {1}))"
  def_macro :get_x, "(((Point *){0})->x)"
  def_macro :get_y, "(((Point *){0})->y)"
  def_macro :set_x, "(((Point *){0})->x = {1})"
  def_macro :set_y, "(((Point *){0})->y = {1})"
  def_macro :free_point, "free((void *){0})"
end

# Create point on heap
pt = MyFFI.create_point(10, 20)

# Verify initial values
x1 = MyFFI.get_x(pt)
y1 = MyFFI.get_y(pt)
printf("Point: %d, %d\n", x1, y1)

# Modify values
MyFFI.set_x(pt, 100)
MyFFI.set_y(pt, 200)

x2 = MyFFI.get_x(pt)
y2 = MyFFI.get_y(pt)
printf("Modified Point: %d, %d\n", x2, y2)

# Free heap memory
MyFFI.free_point(pt)
