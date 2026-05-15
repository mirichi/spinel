module RAY
  ffi_lib "raylib"
  ffi_cflags "-I/usr/local/include -L/usr/local/lib"

  # RaylibをWindowsでスタティックリンクする場合は必要
  ffi_lib "gdi32"
  ffi_lib "winmm"

  # raylibヘッダをinclude
  ffi_include "raylib.h"

  # Color 構造体を定義
  ffi_struct :Color, [[:r, :uint8], [:g, :uint8], [:b, :uint8], [:a, :uint8]]

  # 関数群の定義
  ffi_func :InitWindow, [:int, :int, :str], :void
  ffi_func :ClearBackground, [:Color], :void
  ffi_func :BeginDrawing, [], :void
  ffi_func :EndDrawing, [], :void
  ffi_func :WindowShouldClose, [], :bool
  ffi_func :CloseWindow, [], :void
end
# ウィンドウの初期化
RAY.InitWindow(400, 300, "Spinel Struct Argument Test")
# Color構造体のインスタンスを作成
bg_color = RAY::Color.new(0, 121, 241, 255) # Raylibの青っぽい背景色
while RAY.WindowShouldClose() == false
  RAY.BeginDrawing()
  
  # ここで Color 構造体が値渡しでC言語側に渡されます！
  RAY.ClearBackground(bg_color)
  
  RAY.EndDrawing()
end
RAY.CloseWindow()
