#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite assertions
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

_bashTestSuite_pass() {
    TEST_PASSED=$((TEST_PASSED + 1))
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    bashTestSuite_ok "$1"
}

_bashTestSuite_fail() {
    TEST_FAILED=$((TEST_FAILED + 1))
    BASH_TESTSUITE_FAILED=$TEST_FAILED
    bashTestSuite_fail "$1"
}

# Description: Prefer product console() when already loaded; else suite print.
_bashTestSuite_msg() {
    if declare -f console &>/dev/null; then
        console "$1"
    else
        bashTestSuite_print "$1"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if [[ "$haystack" == *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        _bashTestSuite_msg "  ✓ ${label} contains: ${needle}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        _bashTestSuite_msg "  ✗ ${label} missing: ${needle}"
    fi
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    BASH_TESTSUITE_FAILED=$TEST_FAILED
}

assert_not_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if [[ "$haystack" != *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        _bashTestSuite_msg "  ✓ ${label} excludes: ${needle}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        _bashTestSuite_msg "  ✗ ${label} should not contain: ${needle}"
    fi
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    BASH_TESTSUITE_FAILED=$TEST_FAILED
}

# NDS settings validators (validate_<name>) — kept for existing suites.
assert_valid() {
    local input_name="$1" value="$2"
    if "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        _bashTestSuite_msg "  ✓ valid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        _bashTestSuite_msg "  ✗ expected valid: $value"
    fi
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    BASH_TESTSUITE_FAILED=$TEST_FAILED
}

assert_invalid() {
    local input_name="$1" value="$2"
    if ! "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        _bashTestSuite_msg "  ✓ invalid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        _bashTestSuite_msg "  ✗ expected invalid: $value"
    fi
    BASH_TESTSUITE_PASSED=$TEST_PASSED
    BASH_TESTSUITE_FAILED=$TEST_FAILED
}
