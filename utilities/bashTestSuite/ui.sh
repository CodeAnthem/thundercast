#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite UI (minimal)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

bashTestSuite_print() {
    printf '%s\n' "${1:-}" >&2
}

bashTestSuite_ok() {
    bashTestSuite_print "  ✓ ${1:-}"
}

bashTestSuite_fail() {
    bashTestSuite_print "  ✗ ${1:-}"
}

bashTestSuite_section() {
    local title="${1:-}"
    bashTestSuite_print ""
    bashTestSuite_print "  +--------------------------------------------------------+"
    bashTestSuite_print "  |  ${title}"
    bashTestSuite_print "  +--------------------------------------------------------+"
}

bashTestSuite_title() {
    local title="${1:-}"
    bashTestSuite_print ""
    bashTestSuite_print "  +--------------------------------------------------------+"
    bashTestSuite_print "  | === ${title} ==="
    bashTestSuite_print "  +--------------------------------------------------------+"
}

bashTestSuite_summary() {
    local passed="${BASH_TESTSUITE_PASSED:-${TEST_PASSED:-0}}"
    local failed="${BASH_TESTSUITE_FAILED:-${TEST_FAILED:-0}}"
    bashTestSuite_print ""
    bashTestSuite_section "Test summary"
    bashTestSuite_print "  Passed: ${passed}"
    bashTestSuite_print "  Failed: ${failed}"
    bashTestSuite_print "  Total:  $((passed + failed))"
    if [[ "$failed" -eq 0 ]]; then
        bashTestSuite_print "  [OK] - All tests passed"
        return 0
    fi
    bashTestSuite_print "  [FAIL] - ${failed} test(s) failed"
    return 1
}
