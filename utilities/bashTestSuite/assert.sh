#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite assertions
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-20
# ==================================================================================================

_bts_appendFailLog() {
    local msg="${1:-}"
    [[ -n "${bts_config[fail_log]:-}" ]] || return 0
    local file="${bts_config[current_file]:-}"
    local suite="${bts_config[suite]:-}"
    local ctx="${file}"$'\t'"${suite}"
    {
        if [[ "${bts_config[log_context]:-}" != "$ctx" ]]; then
            printf '\nFILE %s\nSUITE %s\n' "$file" "$suite"
            bts_config[log_context]="$ctx"
        fi
        printf 'FAIL %s\n' "$msg"
    } >>"${bts_config[fail_log]}"
}

bts_pass() {
    bts_config[passed]=$((bts_config[passed] + 1))
    [[ "${bts_config[format]}" == 1 ]] || return 0
    _bts_case_ok "$1"
}

bts_fail() {
    bts_config[failed]=$((bts_config[failed] + 1))
    _bts_appendFailLog "$1"
    [[ "${bts_config[format]}" == 1 ]] || return 0
    _bts_case_fail "$1"
}

assert_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if [[ "$haystack" == *"$needle"* ]]; then
        bts_pass "${label} contains: ${needle}"
    else
        bts_fail "${label} missing: ${needle}"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" label="${3:-output}"
    if [[ "$haystack" != *"$needle"* ]]; then
        bts_pass "${label} excludes: ${needle}"
    else
        bts_fail "${label} should not contain: ${needle}"
    fi
}
