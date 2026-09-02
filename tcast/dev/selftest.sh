#!/usr/bin/env bash
# ==================================================================================================
# tcast - Self-test (bashTestSuite + *_TEST.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-01 | Modified: 2026-09-02
# ==================================================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TCAST_ROOT="${ROOT}/tcast"
export TCAST_ROOT

# shellcheck disable=SC1091
source "${ROOT}/utilities/bashTestSuite/main.sh"

ver="$(tr -d '[:space:]' < "${TCAST_ROOT}/VERSION")"
bashTestSuite_title "tcast v${ver} self-tests"
bashTestSuite_sourceTree "${TCAST_ROOT}" || exit 1

TEST_PASSED=0
TEST_FAILED=0
run_named_suite "tcast_smoke" suite_tcast_smoke

BASH_TESTSUITE_PASSED=$TEST_PASSED
BASH_TESTSUITE_FAILED=$TEST_FAILED
print_test_summary
