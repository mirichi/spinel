def test_interp(str1, str2)
  inline_c "printf(\"interpolated string: %s %s\\n\", #{str1}, #{str2})"
  nil
end

test_interp("Hello", "World")
