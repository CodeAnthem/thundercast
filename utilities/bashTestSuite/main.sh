#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite (shared product-agnostic bash test framework)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# Description:   Assertions, suite runner, tiny UI. No product logger/UI dependency.
# ==================================================================================================

_BASH_TESTSUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_BASH_TESTSUITE_DIR}/ui.sh"
# shellcheck disable=SC1091
source "${_BASH_TESTSUITE_DIR}/assert.sh"

declare -g BASH_TESTSUITE_PASSED=0
declare -g BASH_TESTSUITE_FAILED=0
declare -g BASH_TESTSUITE_SUITE=""

# Compat aliases used by existing NDS suites
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SUITE=""

# Description: Source one file (for tests that need helpers).
# Arguments:
# - path: <String>
# Returns:
# - <Bool> 0 when sourced
bashTestSuite_sourceFile() {
    local path="${1:-}"
    [[ -n "$path" && -f "$path" ]] || return 1
    # shellcheck disable=SC1090
    source "$path"
}

# Description: Find and source every *_TEST.sh under root (sorted).
# Arguments:
# - root: <String> Directory to walk
# Returns:
# - <Bool> 0 when walk completes (individual source failures abort)
bashTestSuite_sourceTree() {
    local root="${1:?root}"
    local f
    [[ -d "$root" ]] || return 1
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        bashTestSuite_sourceFile "$f" || return 1
    done < <(find "$root" -type f -name '*_TEST.sh' | sort)
    return 0
}

# Description: Run one named suite function.
# Arguments:
# - name: <String> Display name
# - fn:   <String> Function name
bashTestSuite_runSuite() {
    local name="$1" fn="$2"
    BASH_TESTSUITE_SUITE="$name"
    TEST_SUITE="$name"
    bashTestSuite_section "Suite: $name"
    "$fn"
}

# Compat for existing suites
run_named_suite() {
    bashTestSuite_runSuite "$1" "$2"
}

# Description: Run every function whose name starts with suite_ (sorted).
bashTestSuite_runAllSuites() {
    local fn name
    local -a suites=()
    BASH_TESTSUITE_PASSED=0
    BASH_TESTSUITE_FAILED=0
    TEST_PASSED=0
    TEST_FAILED=0
    while IFS= read -r fn; do
        [[ "$fn" == suite_* ]] || continue
        suites+=("$fn")
    done < <(declare -F | awk '{print $3}' | sort)
    if ((${#suites[@]} == 0)); then
        bashTestSuite_fail "no suite_* functions registered after sourcing *_TEST.sh"
        BASH_TESTSUITE_FAILED=1
        TEST_FAILED=1
        bashTestSuite_summary
        return 1
    fi
    for fn in "${suites[@]}"; do
        name="${fn#suite_}"
        bashTestSuite_runSuite "$name" "$fn"
        BASH_TESTSUITE_PASSED=$TEST_PASSED
        BASH_TESTSUITE_FAILED=$TEST_FAILED
    done
    bashTestSuite_summary
}

print_test_summary() {
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    BASH_TESTSUITE_FAILED=$TEST_FAILED
    bashTestSuite_summary
}
