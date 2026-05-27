#!/bin/sh
# Top-level driver for spinel-gem tests. Runs unit + E2E and aggregates result.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

rc=0
echo "== Unit tests (Spinelfile DSL) =="
ruby "$SCRIPT_DIR/spinelfile_test.rb" || rc=1
echo
echo "== E2E tests (spinel-gem install + spinel -E) =="
sh "$SCRIPT_DIR/run_e2e.sh" || rc=1

exit $rc
