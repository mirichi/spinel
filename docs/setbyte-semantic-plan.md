# String#setbyte semantic-preserving plan (改訂版: frozen literal 採用)

## 方針

**spinel は `# frozen_string_literal: true` がグローバルに有効な Ruby として振る舞う。**

- string literal は frozen (rodata に置く既存設計と整合)
- 変更操作 (setbyte, <<, concat, replace, !-suffix mutators, …) を frozen literal に対して行うと `FrozenError` を raise
- mutable string が必要なら `.dup` で heap allocate

## 何故これが正しいか

1. **spinel の既存設計と一致**: literal は既に rodata に dedup されている。 frozen として扱うのが本質的に正しい
2. **Ruby の方向性**: 3.0+ で frozen-string-literal を推奨、 将来的にデフォルト化の議論あり
3. **subset の identity と一致**: spinel は Ruby のサブセット → サブセット内では一貫した強い保証を提供する設計
4. **silent failure を排除**: no-op は最悪。 raise なら user は問題を即座に発見し `.dup` で fix できる
5. **aliasing 曖昧さの解消**: COW にあった `a = "ab"; b = a; a.setbyte(...)` の divergence 問題が起きない (mutation 試行で必ず raise)

## 現在の問題

`commit bbfc3b3` (sp_str_setbyte) の挙動:
- heap (0xfe/0xfc/0xfd) → mutate ✓
- literal (0xff) → **silent no-op** ✗
- FFI / unknown → silent no-op ✗

silent no-op は受け入れられない。 frozen literal semantics で raise に切り替える。

## Phase 1: setbyte の frozen literal raise

### Runtime 変更

`lib/sp_runtime.h` の `sp_str_setbyte`:

```c
static inline mrb_int sp_str_setbyte(const char *s, mrb_int i, mrb_int v) {
  if (!s) return v;
  unsigned char m = ((const unsigned char *)s)[-1];
  if (m == 0xfe || m == 0xfc || m == 0xfd) {
    ((char *)s)[i] = (char)v;
    return v;
  }
  /* literal (0xff) or FFI / unknown -> frozen, raise. spinel
     treats all string literals as frozen-string-literal: true. */
  sp_raise_cls("FrozenError", "can't modify frozen String");
  return v;  /* unreachable; longjmp via sp_raise_cls */
}
```

### Codegen 変更

なし。 既存の `sp_str_setbyte(rc, idx, val)` emit がそのまま runtime check を経由する。

### Test 更新

`test/str_method_nil_arg_no_segv.rb` の setbyte 部分が FrozenError raise するように:

```ruby
# 旧:
(str = "a")
str.setbyte(0, 98)
puts str   # spinel: "a" (mutation dropped)

# 新:
(str = "a")
begin
  str.setbyte(0, 98)
  puts "no raise: " + str
rescue FrozenError => e
  puts "frozen: " + e.message
end
```

期待値 `"frozen: can't modify frozen String"`。

### 新 regression test (`test/str_setbyte_frozen_literal.rb`)

```ruby
# Spinel adopts `# frozen_string_literal: true` semantics globally:
# string literals are immutable; setbyte on a literal raises
# FrozenError. To mutate, use .dup or a fresh heap-allocated
# string from .+/.concat etc.

# Literal: raises
begin
  s = "abc"
  s.setbyte(0, 67)
  puts "no raise"
rescue FrozenError => e
  puts "literal: " + e.message
end

# Dup'd: mutates
s2 = "abc".dup
s2.setbyte(0, 67)
puts s2   # Cbc

# String#+: mutates (returns fresh heap)
s3 = "x" + "y"
s3.setbyte(0, 90)
puts s3   # Zy

# ivar on heap string: mutates
class C
  attr_reader :buf
  def initialize; @buf = "abc".dup; end
  def hit; @buf.setbyte(0, 67); end
end
c = C.new
c.hit
puts c.buf  # Cbc
```

期待値:
```
literal: can't modify frozen String
Cbc
Zy
Cbc
```

## Phase 2: 他の mutator にも適用 (follow-up)

Phase 1 が安定したら、 同じ frozen-check を以下にも適用:

| Method | 現状 | 目標 |
|---|---|---|
| String#<< | (調査要) | literal recv で FrozenError |
| String#concat | (調査要) | 同上 |
| String#replace | (調査要) | 同上 |
| String#chomp! | (調査要) | 同上 |
| String#strip! | (調査要) | 同上 |
| String#squeeze! | (調査要) | 同上 |
| String#gsub!, sub! | (調査要) | 同上 |
| String#upcase!, downcase! 等 | (調査要) | 同上 |

各 method の codegen で marker check を runtime emit するか、 共通 helper を経由させる。 Phase 2 は別 issue で個別に対応。

## Phase 3: ユーザー視点の error message 改善

`FrozenError` の message を spinel-aware に:
- `can't modify frozen String (literal "<content>")` のように literal 文字列の先頭 32 文字を含めると debug 容易
- ただし stack trace が無いので line 情報は出ない (既存の sp_raise_cls 仕様)

Phase 3 はオプション。

## Aliasing semantics — frozen literal 採用で完全互換

| Pattern | spinel (frozen literal) | MRI (frozen literal pragma) | 一致? |
|---|---|---|---|
| `a = "ab"; a.setbyte(0, 67)` | FrozenError raise | FrozenError raise | ✅ |
| `a = "ab"; b = "ab"; a.setbyte(0, 67)` | FrozenError raise | FrozenError raise | ✅ |
| `a = "ab".dup; b = a; a.setbyte(0, 67)` | mutate, b="Cb" (shared) | mutate, b="Cb" (shared) | ✅ |
| `a = "ab".dup; a.setbyte(0, 67)` | mutate | mutate | ✅ |

frozen literal pragma 有効な Ruby と完全一致。

## bm_ruby_xor の挙動

```ruby
def xor_strings(a, b)
  result = a.dup    # heap (0xfe)
  result.setbyte(i, ...)  # heap path で mutate
  result
end
```

dup で heap 化されるので問題なし。 Phase 1 で PASS。

## 影響範囲

| File | 変更 | 行数 |
|---|---|---|
| lib/sp_runtime.h | `sp_str_setbyte` を frozen-raise 化 | ~5 |
| test/str_method_nil_arg_no_segv.rb | literal setbyte を rescue で wrap | ~8 |
| test/str_method_nil_arg_no_segv.rb.expected | "a" → "frozen: ..." | ~1 |
| test/str_setbyte_frozen_literal.rb | 新 regression test | ~25 |
| test/str_setbyte_frozen_literal.rb.expected | | ~4 |
| docs/SPINEL-SEMANTICS.md (任意) | frozen-literal-default の document | ~30 |

## 検証

- `make test`: 628/0/0 → 629/0/0 (新 regression test 追加、 既存 test の expected 更新)
- `make bench`: 57/0/0/0 維持 (bm_ruby_xor は dup → heap path)
- `make optcarrot`: checksum 59662 維持

## Risks

1. **既存 user code の breakage**: spinel で動いていた `s = "abc"; s.setbyte(...)` が raise に変わる
   - 緩和: error message が明確、 `.dup` で簡単に修正可能
   - spinel は Ruby subset、 frozen literal pragma に依存することは subset 内では妥当
2. **他の mutator が consistent でない**: Phase 1 では setbyte のみ。 String#<< 等は別挙動のまま
   - 緩和: Phase 2 で順次対応、 個別 issue で track
3. **FFI / unknown marker への扱い**: 現在は literal 同様 raise (defensive)
   - FFI で返った文字列は通常 spinel-side で `sp_str_dup_external` 経由して heap 化されているので実害は少ない

## 実装順

1. `sp_str_setbyte` を frozen-raise 化
2. `test/str_method_nil_arg_no_segv` 更新
3. 新 regression test `str_setbyte_frozen_literal` 追加
4. `make test` / `make bench` / `make optcarrot` 全通し
5. commit + push
6. Phase 2 (他の mutator) を別 issue として open
