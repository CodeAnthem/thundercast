#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite execute one test file (current process)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================

_bts_sourceFile() {
    local path="${1:-}"
    [[ -n "$path" && -f "$path" ]] || return 1
    # shellcheck disable=SC1090
    source "$path"
}

_bts_executeFile() {
    local file="$1"
    local fn
    local -A seen=()
    local -a suites=()

    bts_config[current_file]="$file"

    while read -r _ _ fn; do
        [[ -n "$fn" ]] || continue
        seen["$fn"]=1
    done < <(declare -F)

    _bts_sourceFile "$file" || return 1

    while read -r _ _ fn; do
        [[ "$fn" == suite_* ]] || continue
        [[ -z "${seen[$fn]:-}" ]] || continue
        suites+=("$fn")
    done < <(declare -F)

    if ((${#suites[@]} == 0)); then
        bts_fail "no suite_* functions in ${file}"
        return 0
    fi

    local suite_rc=0
    for fn in "${suites[@]}"; do
        bts_config[suite]="${fn#suite_}"
        bts_section "Suite: ${bts_config[suite]}"
        set +e
        "$fn"
        suite_rc=$?
        set -e
        if ((suite_rc != 0)); then
            bts_fail "suite ${bts_config[suite]} returned non-zero"
        fi
    done
}
