#!/usr/bin/env bash
# ==================================================================================================
# NDS - Binary stubs for cook tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

# shellcheck source=setup_TEST.sh
source "$(dirname "${BASH_SOURCE[0]}")/setup_TEST.sh"

suite_stubBins() {
    local _log _out
    nds_test_stubBins parted cryptsetup || { bts_fail "stub dir failed"; return; }
    parted /dev/stub --script -- mklabel gpt
    export NDS_TEST_BIN_RC_CRYPTSETUP=7
    cryptsetup luksFormat /dev/stub || true
    _log=$(<"$NDS_TEST_BIN_LOG")
    if [[ "$_log" == $'parted /dev/stub --script -- mklabel gpt\ncryptsetup luksFormat /dev/stub' ]]; then
        bts_pass "stub binaries record name and arguments"
    else
        bts_fail "bin log was '${_log}'"
    fi
    _out=0
    cryptsetup open /dev/stub || _out=$?
    if [[ "$_out" -eq 7 ]]; then
        bts_pass "NDS_TEST_BIN_RC_CRYPTSETUP forces the exit code"
    else
        bts_fail "cryptsetup status was '${_out}'"
    fi
    _dir=$NDS_TEST_BIN_DIR
    nds_test_stubBins_drop
    if [[ $PATH != ${_dir}:* && ! -d $_dir ]]; then
        bts_pass "drop restores PATH and removes the shims"
    else
        bts_fail "stub dir still on PATH"
    fi
}
