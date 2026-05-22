# Bigint promotion: detection + escape hatch

Working notes (not for commit; .gitignore'd via /tmp-style scratch).

## The undecidable core

"Does this Integer ever exceed 2^63?" reduces to value-range analysis,
which is undecidable in general. No static pass will ever close this
soundly for arbitrary Ruby. We need to accept that and design around it.

## Spectrum of strategies

| Strategy | Cost | Coverage | Notes |
|---|---|---|---|
| (1) Always bigint | ~10x slowdown for all int math | 100% | CRuby's choice. Negates spinel's "fast AOT" pitch. |
| (2) Pattern-based auto-detect (current) | None when not detected | Specific shapes only | `x *= y` in loops, fib-style accumulators. Lots of false negatives. |
| (3) Type-annotated (RBS / explicit) | None when not used | Whatever user marks | Requires user action. Most precise. |
| (4) Boundary promotion (tagged union) | Per-op overflow check + dispatch | 100% | Same cost shape as (1) but lazier promotion. Still costly per arithmetic op. |
| (5) Profile-guided | Toolchain complexity | High with good corpus | Overkill for spinel's size. |

Spinel sits between (2) and (3) today: pattern detection covers the
canonical fibonacci / factorial-in-loop shapes; everything else falls
through to mrb_int and silently overflows.

## User's CLI-flag proposal

> Pattern detection by default; for undetectable cases, a CLI flag
> ("this program uses bigint, every integer op is overflow-checked
> and slower").

### Strengths

- Simple mental model: auto when possible, flag when not.
- Zero source changes for the safety-net path.
- Clear responsibility split: best-effort detector + user-controlled
  fallback for the cover gaps.

### Concerns

1. **Whole-program granularity is too coarse.** Real programs commonly
   want bigint for one method while keeping the hot loop on mrb_int.
   NES emulator with a SHA-256 checksum: the per-op overflow check
   would tank the emulator path. Single flag forces an
   all-or-nothing choice that erodes spinel's main selling point.

2. **Implementation needs tagged-int representation for every local.**
   Today spinel emits `mrb_int lv_x = 5;` and arithmetic compiles to
   single native ops. Adding overflow-check + auto-promote means each
   int local has to be able to hold either a small int OR an
   sp_bigint pointer — i.e. tagged at the C level (sp_RbVal-shaped).
   Each arithmetic op becomes:
   ```c
   if (lv_x.tag==SMALL && lv_y.tag==SMALL) {
     if (!__builtin_mul_overflow(lv_x.v.i, lv_y.v.i, &r)) {
       lv_z = small(r);
     } else {
       lv_z = bigint(sp_bigint_mul_si(lv_x.v.i, lv_y.v.i));
     }
   } else {
     lv_z = bigint(sp_bigint_mul_poly(...));
   }
   ```
   This is the CRuby Fixnum/Bignum shape. Spinel's "AOT to native int"
   advantage gets traded for CRuby-like runtime overhead.

3. **Two communities, one flag.** The "I want speed even if I have to
   write annotations" user and the "I want correctness no matter how
   slow" user have opposite preferences. A single boolean doesn't serve
   either well; it serves both badly.

## Better granularity

Listing escape hatches finest-to-coarsest:

### A. RBS-typed bigint return / param
```rbs
def factorial: (Integer n) -> BigInt
```
The function's return slot and any local assigned from it are bigint.
Surrounding code stays mrb_int. Best granularity for cost-conscious
users. Reuses the existing RBS plumbing.

### B. Source-level `BigInt(...)` cast
```ruby
n = BigInt(gets.to_i)
result = (1..n).inject(:*)
```
`BigInt(expr)` is an explicit type-conversion point. From that LV
onward arithmetic dispatches to sp_bigint. Smallest surface change in
the compiler (just another constructor).

### C. `--strict-bigint-check` warning mode
Analyzer walks the program looking for "this multiply / power / chain
might overflow given the inputs we can see" and emits a warning
pointing at the source line. User reads the warnings, fixes via A
or B. Pattern: same warn_unresolved_call shape we use today. No
runtime cost.

### D. `--all-bigint` whole-program flag (user's original proposal)
Last-resort, every int local becomes tagged. Documentation must
prominently say "expect 5-10x slowdown on integer-hot code". Right
choice for someone running a small Ruby script through spinel just
to get a binary, where they'd rather have correctness than speed.

## Recommended priority order

1. Extend pattern detection (the existing approach, more shapes):
   - `x ** n` and `Integer#pow`
   - Recursive accumulators (`def f(n); n<=1 ? 1 : n*f(n-1); end`)
   - `gets.to_i` / `ARGV[i].to_i` flowing into multiply chain
   - Whole-array `inject(:*)` / `reduce(:+)` over numeric arrays where
     the array source isn't bounded by a static literal
   These are syntactically detectable, decidable individually, and
   catch the common scientific / competitive-programming shapes.

2. `BigInt(...)` explicit cast — small compiler change, gives the
   "ergonomic narrow" path.

3. RBS-typed bigint declarations — surfaces the existing bigint type
   through the existing RBS pipeline.

4. `--strict-bigint-check` analyzer warning — closes the loop by
   pointing the user at gaps the detector missed.

5. `--all-bigint` whole-program flag — last resort, document the cost.

Step 1 is the "near-term plan" from project_bigint_promotion_plan.md.
Steps 2-5 are the escape-hatch fan-out.

## Why I'd push back on starting with the whole-program flag

The single flag is the easiest to ship, but it locks the project into
a future where bigint-needing users compile slow and bigint-not-needing
users got nothing new. Whereas A/B/C in any order each delivers a
narrower, faster improvement for the common case, and D becomes the
no-thinking-required fallback once nothing else fits.

Phrased differently: D answers "how do I make spinel safe for bigint?"
A-C answer "how do I make spinel useful for someone whose program
sometimes needs bigint?" The second question is the one the
ecosystem benefits from.
