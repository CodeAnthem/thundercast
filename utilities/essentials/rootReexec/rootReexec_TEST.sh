#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Root Reexec tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_rootReexec() {
    local rc
    local -a preserve_vars=()

    essentials_test_load rootReexec

    if [[ "${__ROOTREEXEC_INITIALIZED:-false}" == true ]]; then
        bts_pass "ROOTREEXEC_ROOT=false loads without exec"
    else
        bts_fail "__ROOTREEXEC_INITIALIZED was not set"
    fi

    ROOTREEXEC_TEST_KEEP=one
    export ROOTREEXEC_TEST_KEEP
    preserve_vars=()
    _essentials_rootReexec_collectEnv preserve_vars "ROOTREEXEC_TEST_" ""
    if [[ "${preserve_vars[*]}" == "ROOTREEXEC_TEST_KEEP=one" ]]; then
        bts_pass "collectEnv keeps prefix matches"
    else
        bts_fail "prefix collect was '${preserve_vars[*]}'"
    fi

    KEEP_NAMED=two
    preserve_vars=()
    _essentials_rootReexec_collectEnv preserve_vars "" "KEEP_NAMED"
    if [[ "${preserve_vars[*]}" == "KEEP_NAMED=two" ]]; then
        bts_pass "collectEnv keeps named vars"
    else
        bts_fail "named collect was '${preserve_vars[*]}'"
    fi
    unset KEEP_NAMED ROOTREEXEC_TEST_KEEP

    rc=0
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[ROOTREEXEC_ROOT]=true
essentials_test_load rootReexec
' _rr_missing "$_ESSENTIALS_ROOT" 2>/dev/null || rc=$?  # RootReexec: ROOTREEXEC_SCRIPT is required…
    if [[ $EUID -eq 0 ]]; then
        if [[ "$rc" -eq 0 ]]; then
            bts_pass "already root does not require ROOTREEXEC_SCRIPT"
        else
            bts_fail "already root missing ROOTREEXEC_SCRIPT rc=$rc"
        fi
    elif [[ "$rc" -ne 0 ]]; then
        bts_pass "ROOTREEXEC_ROOT=true without ROOTREEXEC_SCRIPT exits"
    else
        bts_fail "missing ROOTREEXEC_SCRIPT did not exit"
    fi
}
