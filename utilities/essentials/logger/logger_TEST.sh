#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger count tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-18
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_logger_counts() {
    essentials_test_load logger

    logger_markError
    if logger_hasError; then
        bts_pass "logger_markError sets hasError"
    else
        bts_fail "logger_markError did not set hasError"
    fi

    logger_markWarn
    if logger_hasWarn; then
        bts_pass "logger_markWarn sets hasWarn"
    else
        bts_fail "logger_markWarn did not set hasWarn"
    fi

    logger_resetCounts
    if ! logger_hasError && ! logger_hasWarn; then
        bts_pass "counts start empty after reset"
    else
        bts_fail "counts not empty after reset"
    fi

    logger_resetCounts
    error "count me" 2>/dev/null
    if logger_hasError && ! logger_hasWarn; then
        bts_pass "error() increments error count"
    else
        bts_fail "error() did not increment error count"
    fi
    logger_resetCounts
}
