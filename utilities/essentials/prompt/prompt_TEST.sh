#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Prompt tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-23
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_prompt_isolated() {
    local rc=0
    __PROMPT_ISOLATED_ERR=""
    __PROMPT_ISOLATED_ERR=$(
        bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
essentials_test_load prompt
tty_ok() { return 0; }
tty_begin() { return 0; }
tty_end() { return 0; }
tty_setPreset() { return 0; }
tty_allow() { return 0; }
tty_pending() { return 1; }
tty_drain() { return 0; }
eval "$2"
' _prompt_iso "$_ESSENTIALS_ROOT" "$1" 2>&1
    ) || rc=$?
    return "$rc"
}

suite_prompt() {
    local rc tmp

    essentials_test_load prompt

    bts_section "Parse"

    rc=0
    tmp=$(mktemp)
    prompt 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q -- '--type or message required' "$tmp"; then
        bts_pass "prompt needs type or message"
    else
        bts_fail "empty prompt rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt --type select 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q -- 'requires --options' "$tmp"; then
        bts_pass "select requires --options"
    else
        bts_fail "select options rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt --type multi-select 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q -- 'requires --options' "$tmp"; then
        bts_pass "multi-select requires --options"
    else
        bts_fail "multi-select options rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    declare -a _sel_opts=(a)
    declare -a _sel_pre=(a)
    prompt --type select --options _sel_opts --selected _sel_pre 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q -- '--selected is only valid' "$tmp"; then
        bts_pass "selected rejected on select"
    else
        bts_fail "selected-on-select rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt --type multi-select --options _sel_opts --default a 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q -- '--default is not valid' "$tmp"; then
        bts_pass "default rejected on multi-select"
    else
        bts_fail "default-on-multi rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt --type nope 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q 'unknown type' "$tmp"; then
        bts_pass "unknown type fails"
    else
        bts_fail "unknown type rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt -z 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q 'unknown flag' "$tmp"; then
        bts_pass "unknown flag fails"
    else
        bts_fail "unknown flag rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    prompt --type text --hide --mask '*' "X" 2>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 ]] && grep -q 'cannot be combined' "$tmp"; then
        bts_pass "hide and mask conflict"
    else
        bts_fail "hide/mask rc=$rc err=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    bts_section "Results"

    rc=0
    _prompt_isolated '
_keys=(y)
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type confirm "Go" || exit 1
[[ "$UI_PROMPT_RESULT" == y && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "confirm y is submit"
    else
        bts_fail "confirm y rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_keys=(n)
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type confirm -b "Go" || exit 1
[[ "$UI_PROMPT_RESULT" == n && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "confirm n is success"
    else
        bts_fail "confirm n rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_keys=(b)
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
_rc=0
prompt --type confirm -b "Go" || _rc=$?
[[ "$_rc" -eq 2 && "$UI_PROMPT_ACTION" == back ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "confirm back is rc 2"
    else
        bts_fail "confirm back rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_keys=("")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type confirm --default y "Go" || exit 1
[[ "$UI_PROMPT_RESULT" == y && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "confirm enter uses default y"
    else
        bts_fail "confirm default rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
tty_allow() { return 1; }
prompt --type confirm "Go" && exit 1
true
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "confirm fails when tty_allow fails"
    else
        bts_fail "confirm allow-fail rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
declare -a opts=(one two three)
tty_read() {
    local var="${!#}"
    printf -v "$var" "2"
    return 0
}
prompt --type select --options opts "Choice" || exit 1
[[ "$UI_PROMPT_RESULT" == two && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "select stores option value"
    else
        bts_fail "select rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
__UI_MODE=auto
declare -a opts=(one two three)
_keys=(2 "")
_i=0
tty_getc() {
    if (( _i >= ${#_keys[@]} )); then
        return 1
    fi
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type select --options opts "Choice" || exit 1
[[ "$UI_PROMPT_RESULT" == two && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "fancy select number moves and enter submits"
    else
        bts_fail "fancy number rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
__UI_MODE=auto
declare -a opts=(one two three)
_keys=(2)
_i=0
tty_getc() {
    if (( _i >= ${#_keys[@]} )); then
        return 1
    fi
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
rc=0
prompt --type select --options opts "Choice" || rc=$?
[[ "$rc" -eq 4 && -z "$UI_PROMPT_RESULT" && -z "$UI_PROMPT_ACTION" ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "fancy select number does not submit"
    else
        bts_fail "fancy number hold rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
__UI_MODE=auto
declare -a opts=(a b c)
_keys=(1 2 "")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type multi-select --options opts "Pick" || exit 1
mapfile -t _got <<< "$UI_PROMPT_RESULT"
[[ ${#_got[@]} -eq 2 && "${_got[0]}" == a && "${_got[1]}" == b && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "fancy multi number toggles then enter submits"
    else
        bts_fail "fancy multi rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
__UI_MODE=auto
declare -a opts=(a b c)
declare -a pre=(b)
_keys=("")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type multi-select --options opts --selected pre "Pick" || exit 1
[[ "$UI_PROMPT_RESULT" == b && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "multi --selected pre-checks"
    else
        bts_fail "multi selected rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
__UI_MODE=auto
declare -a opts=(a b c)
_keys=("")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type multi-select --options opts "Pick" || exit 1
[[ -z "$UI_PROMPT_RESULT" && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "empty multi submit is success"
    else
        bts_fail "empty multi rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
declare -a opts=(a b)
declare -a pre=(nope)
prompt --type multi-select --options opts --selected pre "Pick" && exit 1
true
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "unknown --selected fails"
    else
        bts_fail "unknown selected rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_keys=(h o s t "")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type text --default nixos "Hostname" || exit 1
[[ "$UI_PROMPT_RESULT" == host && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "text stores line"
    else
        bts_fail "text rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_keys=("")
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
prompt --type text --default nixos "Hostname" || exit 1
[[ "$UI_PROMPT_RESULT" == nixos ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "text empty uses default"
    else
        bts_fail "text default rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
tty_getc() { return 1; }
rc=0
prompt --type text "Name" || rc=$?
[[ "$rc" -eq 4 && -z "$UI_PROMPT_RESULT" && -z "$UI_PROMPT_ACTION" ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "text EOF is status 4"
    else
        bts_fail "text eof rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
tty_read() {
    local var="${!#}"
    printf -v "$var" "DONE"
    return 0
}
prompt --type multiline --end DONE --default fallback "Notes" || exit 1
[[ "$UI_PROMPT_RESULT" == fallback && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "multiline empty uses default"
    else
        bts_fail "multiline default rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
_n=0
tty_read() {
    local var="${!#}"
    if (( _n == 0 )); then
        printf -v "$var" "kept"
        _n=1
        return 0
    fi
    return 1
}
rc=0
prompt --type multiline --end DONE --default fallback "Notes" || rc=$?
[[ "$rc" -eq 4 && -z "$UI_PROMPT_RESULT" && -z "$UI_PROMPT_ACTION" ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "multiline EOF discards lines and skips default"
    else
        bts_fail "multiline eof rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
esc=$(printf "\033")
_keys=("$esc" "[" "5" "~" y)
_i=0
tty_getc() {
    printf -v "$1" "%s" "${_keys[_i]}"
    _i=$((_i + 1))
    return 0
}
tty_pending() { (( _i < ${#_keys[@]} )); }
prompt --type confirm --default n "Go?" || exit 1
[[ "$UI_PROMPT_RESULT" == y && "$UI_PROMPT_ACTION" == submit ]]
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "PageUp does not cancel confirm"
    else
        bts_fail "pageup confirm rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    rc=0
    _prompt_isolated '
prompt --type pause
' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        bts_pass "pause is a no-op when UI_NO_PAUSE"
    else
        bts_fail "pause rc=$rc err=$(printf '%q' "${__PROMPT_ISOLATED_ERR}")"
    fi

    essentials_test_load task
    rc=0
    tmp=$(mktemp)
    taskStart "hanging" 2>"$tmp"
    prompt --type pause 2>>"$tmp" || rc=$?
    if [[ "$rc" -ne 0 || "$__TASK_NAME" != hanging ]]; then
        bts_fail "prompt take name=${__TASK_NAME} rc=$rc"
    else
        bts_pass "prompt take keeps task name"
    fi
    taskCancel 2>/dev/null  # \r\033[K
    rm -f "$tmp"
}
