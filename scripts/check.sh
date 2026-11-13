#!/bin/bash
# Local pre-flight: unit tests, a release build, and shellcheck (if installed).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

step() {
  local label="$1"; shift
  echo "── $label ──"
  if "$@"; then echo "  ✓ $label"; else echo "  ✗ $label FAILED"; fail=1; fi
}

step "swift test" swift test
step "build app" ./scripts/build.sh
if command -v shellcheck >/dev/null 2>&1; then
  step "shellcheck" shellcheck scripts/*.sh
else
  echo "── shellcheck ── not installed; skipping (brew install shellcheck)."
fi

exit $fail
