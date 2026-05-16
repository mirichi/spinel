module MyExt
  def self.add(a, b)
    a + b
  end

  def self.greet(name)
    "Hello " + name
  end
end

# 型推論させるためのダミー呼び出し
# 少しイケてないがシンプルな解決策として採用
MyExt.add(1, 2)
MyExt.greet("world")
