#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test framework (read-only — does not modify the system)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-06-29
# Description:   Shared assertions and suite runner for NDS self-tests
# ==================================================================================================

declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SUITE=""

assert_valid() {
    local input_name="$1"
    local value="$2"

    if "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ valid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ expected valid: $value"
    fi
}

assert_invalid() {
    local input_name="$1"
    local value="$2"

    if ! "validate_${input_name}" "$value" 2>/dev/null; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ invalid: $value"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ expected invalid: $value"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local label="${3:-output}"

    if [[ "$haystack" == *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ${label} contains: ${needle}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ${label} missing: ${needle}"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local label="${3:-output}"

    if [[ "$haystack" != *"$needle"* ]]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        console "  ✓ ${label} excludes: ${needle}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        console "  ✗ ${label} should not contain: ${needle}"
    fi
}

run_named_suite() {
    local suite_name="$1"
    shift
    local suite_func="$1"

    TEST_SUITE="$suite_name"
    nds_ui_section_header "Suite: $suite_name"
    "$suite_func"
}

print_test_summary() {
    console ""
    nds_ui_section_header "Test summary"
    console "  Passed: $TEST_PASSED"
    console "  Failed: $TEST_FAILED"
    console "  Total:  $((TEST_PASSED + TEST_FAILED))"

    if [[ $TEST_FAILED -eq 0 ]]; then
        success "All tests passed"
        return 0
    fi
    error "$TEST_FAILED test(s) failed"
    return 1
}

# Description: Reset CONFIG_DATA from a saved copy (suite isolation).
nds_test_reset_config() {
    local key
    CONFIG_DATA=()
    if [[ ${#NDS_TEST_CONFIG_SNAPSHOT[@]} -gt 0 ]]; then
        for key in "${!NDS_TEST_CONFIG_SNAPSHOT[@]}"; do
            CONFIG_DATA["$key"]="${NDS_TEST_CONFIG_SNAPSHOT[$key]}"
        done
    fi
}

# Description: Snapshot CONFIG_DATA for nds_test_reset_config.
nds_test_snapshot_config() {
    local key
    declare -gA NDS_TEST_CONFIG_SNAPSHOT=()
    for key in "${!CONFIG_DATA[@]}"; do
        NDS_TEST_CONFIG_SNAPSHOT["$key"]="${CONFIG_DATA[$key]}"
    done
}
