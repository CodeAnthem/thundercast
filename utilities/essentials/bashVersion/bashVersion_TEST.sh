#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Bash Version tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-22 | Modified: 2026-09-23
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_bashVersion() {
    local rc err major minor

    essentials_test_load bashVersion

    major="${BASH_VERSINFO[0]}"
    minor="${BASH_VERSINFO[1]}"

    rc=0
    bashVersion_check "$major" "$minor" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "check accepts the running major and minor"
    else
        bts_fail "check running version rc=$rc"
    fi

    rc=0
    err=${ bashVersion_check "$major" "$((minor + 1))" 2>&1; } || rc=$?
    if [[ "$rc" -eq 1 && "$err" == *"[BashVersion]"*"requires Bash ${major}.$((minor + 1))"*"found ${BASH_VERSION}"* ]]; then
        bts_pass "check rejects the next minor"
    else
        bts_fail "check next minor rc=$rc err=$(printf '%q' "$err")"
    fi

    rc=0
    err=${ bashVersion_check "$((major + 1))" 0 2>&1; } || rc=$?
    if [[ "$rc" -eq 1 && "$err" == *"[BashVersion]"*"requires Bash $((major + 1)).0"* ]]; then
        bts_pass "check rejects the next major"
    else
        bts_fail "check next major rc=$rc err=$(printf '%q' "$err")"
    fi

    if (( major > 0 )); then
        rc=0
        bashVersion_check "$((major - 1))" 99 || rc=$?
        if [[ "$rc" -eq 0 ]]; then
            bts_pass "check accepts an older major"
        else
            bts_fail "check older major rc=$rc"
        fi
    fi

    rc=0
    err=$(
        bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[BASHVERSION_MAJOR]=99
essentials_config[BASHVERSION_MINOR]=0
essentials_test_load bashVersion
' _bv "$_ESSENTIALS_ROOT" 2>&1
    ) || rc=$?
    if [[ "$rc" -ne 0 && "$err" == *"[BashVersion]"*"requires Bash 99.0"* ]]; then
        bts_pass "init returns failure when configured major.minor is newer"
    else
        bts_fail "init too-new rc=$rc err=$(printf '%q' "$err")"
    fi

    rc=0
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[BASHVERSION_MINOR]=99
essentials_test_load bashVersion
' _bv "$_ESSENTIALS_ROOT" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "unset major skips the check"
    else
        bts_fail "unset major rc=$rc"
    fi
}
