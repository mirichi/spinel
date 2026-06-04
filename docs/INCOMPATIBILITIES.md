# Intentional incompatibilities with CRuby

Spinel aims to be a subset of Ruby: programs it accepts should behave the same
as on CRuby. In a few cases CRuby's behavior depends on a feature Spinel does
not implement, and silently returning a wrong value would be worse than a
visible error. Those deliberate divergences are listed here.

## `Integer#**` with a negative exponent

CRuby evaluates a negative integer exponent to a `Rational`:

```ruby
2 ** -1   # => (1/2)
2 ** -2   # => (1/4)
```

Spinel has no `Rational` type. Rather than silently truncating the result to
`0` (the previous behavior), a negative integer exponent raises:

```ruby
2 ** -1   # RangeError: negative exponent
```

This applies to `Integer#**` / `Integer#pow` across the int, bigint, and
poly-dispatched paths. It is catchable as usual:

```ruby
begin
  2 ** -1
rescue RangeError => e
  # e.message == "negative exponent"
end
```

`Float#**` is unaffected and stays CRuby-compatible, because a float result is
representable:

```ruby
2.0 ** -1   # => 0.5
```

## `String#grapheme_clusters`

CRuby splits a string into Unicode extended grapheme clusters:

```ruby
"á".grapheme_clusters   # => ["á"]   (one cluster: a + combining accent)
```

Correct grapheme segmentation requires shipping and maintaining the Unicode
grapheme-break property tables, which Spinel deliberately does not carry.
`String#grapheme_clusters` and `String#each_grapheme_cluster` are therefore not
supported. For codepoint- or byte-level iteration, use the supported
`String#chars`, `#each_char`, `#codepoints`, or `#bytes`.

## Aliasing the regexp match globals

CRuby's `English` library aliases the punctuation match globals to readable
names:

```ruby
require "English"   # alias $MATCH $&, alias $PREMATCH $`, ...
"hello world" =~ /\w+/
puts $MATCH         # => "hello"
```

In Spinel the match globals (`$&`, `` $` ``, `$'`, `$+`, `$~`) are not ordinary
global-variable storage: a direct read lowers to a special regexp runtime
accessor. Supporting `alias $name $&` would require a separate special-global
alias mechanism plus broader `MatchData` compatibility, which is outside the
intended AOT subset. Aliasing one of these globals is rejected at compile time
rather than falling through to an undefined generated symbol:

```
$ spinel uses_english.rb
Error: global aliasing of regexp special globals is not supported (alias $MATCH $&)
```

Direct reads of the match globals work as usual; only aliasing them is
unsupported. `require "English"` therefore does not compile.

## Flip-flop operator

CRuby supports the flip-flop operator (a `Range` used as a condition, toggled
between its two endpoints):

```ruby
(1..10).each { |i| puts i if (i == 3)..(i == 5) }   # prints 3, 4, 5
```

This is a rarely used feature with surprising hidden per-site state, and Spinel
does not support it; a program using it fails to compile rather than running
with wrong behavior. Use an explicit boolean state variable instead:

```ruby
active = false
(1..10).each do |i|
  active = true if i == 3
  puts i if active
  active = false if i == 5
end
```
