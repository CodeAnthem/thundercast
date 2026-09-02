#!/usr/bin/env bash
# ==================================================================================================
# Fleet - Self-test (bashTestSuite + toolkit *_TEST.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-02
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLKIT="${ROOT}/fleet/toolkit"

# shellcheck disable=SC1091
source "${ROOT}/utilities/bashTestSuite/main.sh"

# shellcheck disable=SC1091
source "${TOOLKIT}/lib/core.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/lib/ui.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/lib/register.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/lib/sops.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/lib/git.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/lib/nodes.sh"
# shellcheck disable=SC1091
source "${TOOLKIT}/menus.sh"

AGE="$(command -v age-keygen || true)"
SOPS="$(command -v sops || true)"
if [[ -z "$AGE" ]]; then
    AGE="$(find /nix/store -maxdepth 4 -type f -name age-keygen 2>/dev/null | head -1)"
fi
if [[ -z "$SOPS" ]]; then
    SOPS="$(find /nix/store -maxdepth 4 -type f -name sops 2>/dev/null | head -1)"
fi
[[ -n "$AGE" && -n "$SOPS" ]] || {
    echo "need age-keygen and sops" >&2
    exit 1
}
export PATH="$(dirname "$AGE"):$(dirname "$SOPS"):$PATH"

# suite_toolkit expects ROOT = toolkit dir
ROOT="$TOOLKIT"
export ROOT
export TCAST_TOOLKIT_ROOT="$TOOLKIT"

ver="$(tr -d '[:space:]' < "${TOOLKIT}/VERSION")"
bashTestSuite_title "Fleet toolkit v${ver} self-tests"
bashTestSuite_sourceTree "${TOOLKIT}" || exit 1

TEST_PASSED=0
TEST_FAILED=0
run_named_suite "toolkit" suite_toolkit

BASH_TESTSUITE_PASSED=$TEST_PASSED
BASH_TESTSUITE_FAILED=$TEST_FAILED
print_test_summary
