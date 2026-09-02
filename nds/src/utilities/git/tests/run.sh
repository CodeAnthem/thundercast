#!/usr/bin/env bash
# ==================================================================================================
# Git utility - standalone entry (delegates to bashTestSuite suite)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-02
# ==================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
NDS_SRC="${ROOT}/nds/src"
SCRIPT_DIR="${NDS_SRC}"
# shellcheck disable=SC1091
source "${ROOT}/utilities/bashTestSuite/main.sh"
# shellcheck disable=SC1091
source "${NDS_SRC}/utilities/git/main.sh"
# shellcheck disable=SC1091
source "${NDS_SRC}/utilities/git/tests/git_utility_TEST.sh"
TEST_PASSED=0
TEST_FAILED=0
suite_git_utility
print_test_summary
[[ "$TEST_FAILED" -eq 0 ]]
