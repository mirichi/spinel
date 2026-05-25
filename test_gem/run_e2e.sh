#!/bin/sh
# spinel-gem end-to-end shell tests. Exits non-zero on any failure.
#
# Scenarios covered:
#   1. basic resolution: gem in adjacent dir, app requires it
#   2. walk-up: app lives in a nested dir, Spinelfile.loadpaths is several levels up
#   3. negative: sidecar removed -> require falls through to stdlib dir and warns
#   4. dedup: same path listed twice in Spinelfile -> sidecar has one entry
#   5. invalid Spinelfile: unsupported source option -> spinel-gem exits non-zero
#   6. missing gem dir: Spinelfile points at nonexistent path -> spinel-gem exits non-zero
#
# Driven from the repo root; SPINEL_BIN / SPINEL_GEM_BIN overridable for sandbox runs.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPINEL_BIN="${SPINEL_BIN:-$REPO_DIR/spinel}"
SPINEL_GEM_BIN="${SPINEL_GEM_BIN:-$REPO_DIR/spinel-gem}"

PASS=0
FAIL=0
FAILED=""

assert_eq() {
  # $1 expected, $2 actual, $3 label
  if [ "$1" = "$2" ]; then
    PASS=$((PASS + 1))
    printf .
  else
    FAIL=$((FAIL + 1))
    FAILED="$FAILED\n  $3:\n    expected: $(printf '%s' "$1" | head -1)\n    actual:   $(printf '%s' "$2" | head -1)"
    printf F
  fi
}

assert_contains() {
  # $1 needle, $2 haystack, $3 label
  case "$2" in
    *"$1"*) PASS=$((PASS + 1)); printf . ;;
    *)      FAIL=$((FAIL + 1)); FAILED="$FAILED\n  $3:\n    needle: $1\n    actual: $2"; printf F ;;
  esac
}

assert_nonzero() {
  # $1 exit code, $2 label
  if [ "$1" -ne 0 ]; then PASS=$((PASS + 1)); printf .
  else FAIL=$((FAIL + 1)); FAILED="$FAILED\n  $2: expected non-zero exit"; printf F
  fi
}

# -- Scenario 1: basic resolution --
T1="$(mktemp -d /tmp/spgem-t1.XXXXXX)"
mkdir -p "$T1/gems/hello/lib"
cat > "$T1/gems/hello/lib/hello.rb" <<'EOF'
module Hello
  def self.greet(n); "Hello, #{n}!"; end
end
EOF
cat > "$T1/Spinelfile" <<'EOF'
gem "hello", path: "./gems/hello"
EOF
cat > "$T1/app.rb" <<'EOF'
require "hello"
puts Hello.greet("e2e")
EOF
(cd "$T1" && "$SPINEL_GEM_BIN" install >/dev/null 2>&1) || { FAIL=$((FAIL+1)); printf F; FAILED="$FAILED\n  scenario1 install failed"; }
out1=$("$SPINEL_BIN" -E "$T1/app.rb" 2>/dev/null)
assert_eq "Hello, e2e!" "$out1" "scenario1 basic resolution"

# -- Scenario 2: walk-up discovery --
mkdir -p "$T1/sub/deeper"
cp "$T1/app.rb" "$T1/sub/deeper/nested.rb"
out2=$("$SPINEL_BIN" -E "$T1/sub/deeper/nested.rb" 2>/dev/null)
assert_eq "Hello, e2e!" "$out2" "scenario2 walk-up discovery"

# -- Scenario 3: negative (no sidecar) --
mv "$T1/Spinelfile.loadpaths" "$T1/Spinelfile.loadpaths.bak"
out3=$("$SPINEL_BIN" -E "$T1/app.rb" 2>&1)
assert_contains "could not be resolved" "$out3" "scenario3 negative case warns"
mv "$T1/Spinelfile.loadpaths.bak" "$T1/Spinelfile.loadpaths"

# -- Scenario 4: dedup of duplicate paths in Spinelfile --
T4="$(mktemp -d /tmp/spgem-t4.XXXXXX)"
mkdir -p "$T4/gems/x/lib"
echo "module X; end" > "$T4/gems/x/lib/x.rb"
cat > "$T4/Spinelfile" <<'EOF'
gem "x",        path: "./gems/x"
gem "x_again",  path: "./gems/x"
EOF
(cd "$T4" && "$SPINEL_GEM_BIN" install >/dev/null 2>&1) || { FAIL=$((FAIL+1)); printf F; FAILED="$FAILED\n  scenario4 install failed"; }
lp_lines=$(wc -l < "$T4/Spinelfile.loadpaths" | tr -d ' ')
assert_eq "1" "$lp_lines" "scenario4 dedup yields one loadpath line"

# -- Scenario 5: invalid Spinelfile (git: source) --
T5="$(mktemp -d /tmp/spgem-t5.XXXXXX)"
cat > "$T5/Spinelfile" <<'EOF'
gem "foo", git: "https://example.com/foo"
EOF
(cd "$T5" && "$SPINEL_GEM_BIN" install >/dev/null 2>&1)
assert_nonzero $? "scenario5 unsupported source fails install"

# -- Scenario 6: missing gem dir --
T6="$(mktemp -d /tmp/spgem-t6.XXXXXX)"
cat > "$T6/Spinelfile" <<'EOF'
gem "ghost", path: "./does/not/exist"
EOF
(cd "$T6" && "$SPINEL_GEM_BIN" install >/dev/null 2>&1)
assert_nonzero $? "scenario6 missing dir fails install"

# Cleanup tmps
rm -rf "$T1" "$T4" "$T5" "$T6"

printf "\n\n"
if [ $FAIL -ne 0 ]; then
  printf "Failed scenarios:%b\n\n" "$FAILED"
  printf "E2E tests: %d pass, %d fail\n" "$PASS" "$FAIL"
  exit 1
fi
printf "E2E tests: %d pass, 0 fail\n" "$PASS"
