#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Session Dir tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_sessionDir() {
    local dir path mode rc inner base

    essentials_test_load sessionDir

    dir=${ runtime_getDir; }
    base="${essentials_config[RUNTIME_BASE]}"
    mode=$(stat -c '%a' "$dir")
    if [[ "$dir" == "$base"/et_* && "$mode" == 700 ]]; then
        bts_pass "root dir created mode 700"
    else
        bts_fail "root dir='$dir' mode='$mode'"
    fi

    if runtime_hasSubdir config && runtime_hasSubdir secrets; then
        bts_pass "config subdirs created"
    else
        bts_fail "missing config/secrets"
    fi

    path=${ runtime_getPath config; }
    if [[ "$path" == "${dir}/config" && -d "$path" ]]; then
        bts_pass "getPath config"
    else
        bts_fail "getPath config was '$path'"
    fi

    runtime_subdirCreate work
    if runtime_hasSubdir work && [[ -d "${dir}/work" ]]; then
        bts_pass "subdirCreate work"
    else
        bts_fail "work subdir missing"
    fi

    runtime_purge config
    if ! runtime_hasSubdir config && runtime_hasSubdir secrets && [[ -d "$dir" ]]; then
        bts_pass "purge config leaves secrets and root"
    else
        bts_fail "batch purge state wrong"
    fi

    rc=0
    runtime_purge nosuch || rc=$?
    if [[ "$rc" -eq 0 ]] && runtime_hasSubdir secrets; then
        bts_pass "unknown purge is a skip"
    else
        bts_fail "unknown purge rc=$rc"
    fi

    rc=0
    runtime_purge 2>/dev/null || rc=$?  # [SessionDir] - Subdir name required
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "purge with no names fails"
    else
        bts_fail "empty purge succeeded"
    fi

    inner=$(trap -p EXIT)
    if [[ "$inner" != *runtime_purge* ]]; then
        bts_pass "no auto EXIT purge trap"
    else
        bts_fail "EXIT trap: $inner"
    fi

    rc=0
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[RUNTIME_PURGE_STALE]=true
base="${essentials_config[RUNTIME_BASE]}"
mkdir -p "${base}/et_stale_0"
essentials_test_load sessionDir
[[ ! -d "${base}/et_stale_0" ]]
runtime_purgeAll
' _rt_stale "$_ESSENTIALS_ROOT" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "PURGE_STALE removes leftover prefix dirs"
    else
        bts_fail "stale purge rc=$rc"
    fi

    rc=0
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[RUNTIME_BASE]="$2"
essentials_test_load sessionDir
' _rt_base "$_ESSENTIALS_ROOT" "$(mktemp)" 2>/dev/null || rc=$?  # mkdir File exists; cannot create base
    if [[ "$rc" -ne 0 ]]; then
        bts_pass "unwritable base fatals"
    else
        bts_fail "file-as-RUNTIME_BASE did not fatal"
    fi

    runtime_purgeAll
    rc=0
    runtime_getDir >/dev/null 2>&1 || rc=$?  # Root directory is not initialized
    if [[ "$rc" -ne 0 && ! -d "$dir" ]]; then
        bts_pass "purgeAll removes root"
    else
        bts_fail "purgeAll rc=$rc dir still at '$dir'"
    fi
}
