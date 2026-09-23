#!/usr/bin/env bash
# ==================================================================================================
# ThunderCast - bashTestSuite UI (case lines, sections, summary)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-20
# ==================================================================================================

_BTS_BORDER="+========================================================+"

_bts_ui_init() {
    local on=0
    case "${bts_config[color]:-}" in
        1) on=1 ;;
        0) on=0 ;;
        *) [[ -z "${NO_COLOR:-}" && -t 2 ]] && on=1 ;;
    esac
    if ((on)); then
        bts_config[ok]=$'\033[1;32mOK\033[0m'
        bts_config[fail]=$'\033[1;31mFAIL\033[0m'
        bts_config[color]=1
    else
        bts_config[ok]=OK
        bts_config[fail]=FAIL
        bts_config[color]=0
    fi
}

_bts_print() {
    printf '%s\n' "${1:-}" >&2
}

bts_section() {
    [[ "${bts_config[format]}" == 1 ]] || return 0
    local title="${1:-}"
    _bts_print ""
    _bts_print "  ${_BTS_BORDER}"
    _bts_print "  |  ${title}"
    _bts_print "  ${_BTS_BORDER}"
}

_bts_case_ok() {
    printf '  [%s] %s\n' "${bts_config[ok]}" "$1" >&2
}

_bts_case_fail() {
    printf '  [%s] %s\n' "${bts_config[fail]}" "$1" >&2
}

_bts_summary() {
    local passed="${bts_config[passed]:-0}"
    local failed="${bts_config[failed]:-0}"
    _bts_print ""
    bts_section "Test summary"
    _bts_print "  Passed: ${passed}"
    _bts_print "  Failed: ${failed}"
    _bts_print "  Total:  $((passed + failed))"
    if [[ "$failed" -eq 0 ]]; then
        _bts_print ""
        _bts_print "  [${bts_config[ok]}] - All tests passed"
        return 0
    fi
    _bts_print "  [${bts_config[fail]}] - ${failed} test(s) failed"
    return 1
}
