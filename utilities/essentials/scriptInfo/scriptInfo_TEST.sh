#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Script Info tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

suite_scriptInfo() {
    local name version dir rc err

    essentials_test_load scriptInfo

    name=${ scriptInfo_get_name; }
    version=${ scriptInfo_get_version; }
    dir=${ scriptInfo_get_dir; }
    if [[ "$name" == "Essentials Test" && "$version" == "0.0.1" && "$dir" == "/tmp/essentials-test" ]]; then
        bts_pass "getters return configured identity"
    else
        bts_fail "got name='$name' version='$version' dir='$dir'"
    fi

    rc=0
    err=$(
        bash -c '
set -euo pipefail
declare -A essentials_config=(
    [SCRIPTINFO_DIR]="/tmp"
    [SCRIPTINFO_NAME]="x"
)
source "$1/scriptInfo/scriptInfo.sh"
' _si_missing "$_ESSENTIALS_ROOT" 2>&1
    ) || rc=$?
    if [[ "$rc" -ne 0 && "$err" == *"[ScriptInfo]"*"SCRIPTINFO_VERSION is required"* ]]; then
        bts_pass "missing SCRIPTINFO_VERSION prints ScriptInfo error"
    else
        bts_fail "missing SCRIPTINFO_VERSION rc=$rc err=$(printf '%q' "$err")"
    fi
}
