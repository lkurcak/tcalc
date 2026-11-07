#!/bin/sh
# Checks tcalc: it type-checks with no warnings, it's formatted, its tests
# pass, and its output for tests/input.txt is tests/expected.txt. Run from
# anywhere; `t` must be on PATH.
# BLESS=1 rewrites tests/expected.txt with what it prints now.
set -eu
cd "$(dirname "$0")/.."

t check --deny-warnings main.t
t fmt --check ./*.t
t test --deny-warnings main.t

# tcalc's output: its input isn't a terminal, so it echoes each line of
# tests/input.txt after the prompt it answers, as a terminal would.
transcript() {
    t main.t < tests/input.txt
}

if [ "${BLESS:-}" = 1 ]; then
    transcript > tests/expected.txt
    echo "wrote tests/expected.txt"
    exit 0
fi

transcript > tests/actual.txt
if ! diff -u tests/expected.txt tests/actual.txt; then
    echo "FAIL: output differs from tests/expected.txt"
    exit 1
fi
rm tests/actual.txt
echo "ok"
