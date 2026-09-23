#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - TTY tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-18 | Modified: 2026-09-21
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_tty_isolated() {
    local rc=0
    __TTY_ISOLATED_ERR=""
    __TTY_ISOLATED_ERR=$(
        bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
essentials_test_load ttyHandler
eval "$2"
' _tty_iso "$_ESSENTIALS_ROOT" "$1" 2>&1
    ) || rc=$?
    return "$rc"
}

suite_tty() {
    local leftover rc found f

    essentials_test_load ttyHandler

    if [[ "${__TTY_GUARD:-0}" == "0" ]]; then
        bts_pass "guard off on load"
    else
        bts_fail "guard was ${__TTY_GUARD:-}"
    fi

    leftover=$(printf 'abcdef' | bash -c '
        n=0
        while IFS= read -r -t 0 -n 256 chunk; do
            n=$((n+1))
            (( n >= 8 )) && break
        done
        cat
        echo
        echo "ITERS=$n"
    ')
    if [[ "$leftover" == *$'\nITERS=8' && "$leftover" == *abcdef* ]]; then
        bts_pass "bash -t 0 does not consume"
    else
        bts_fail "unexpected -t 0 behavior $(printf '%q' "$leftover")"
    fi

    leftover=$(printf 'abcdef' | bash -c '
        while IFS= read -r -t 0; do
            chunk=""
            IFS= read -r -t 0.05 -N 256 chunk || true
            [[ -n "$chunk" ]] || break
        done
        cat
    ')
    if [[ -z "$leftover" ]]; then
        bts_pass "poll-then-read drain consumes"
    else
        bts_fail "drain leftover $(printf '%q' "$leftover")"
    fi

    tty_drain
    if tty_ok; then
        bts_pass "tty_ok true with a controlling TTY"
    else
        bts_pass "tty_ok false without a controlling TTY"
    fi

    tty_restore
    tty_restore
    if [[ "${__TTY_GUARD:-0}" == "0" ]]; then
        bts_pass "tty_restore twice is ok"
    else
        bts_fail "guard after double restore ${__TTY_GUARD:-}"
    fi

    rc=0
    tty_setPreset nope 2>/dev/null || rc=$?
    if (( rc != 0 )); then
        bts_pass "unknown preset fails"
    else
        bts_fail "unknown preset succeeded"
    fi

    tty_setPreset digits
    if [[ "${__TTY_POLICY}" == allow ]] && _tty_charAllowed 5 && ! _tty_charAllowed a && _tty_charAllowed $'\n'; then
        bts_pass "preset digits sets allow 0-9"
    else
        bts_fail "digits policy=${__TTY_POLICY}"
    fi

    if _tty_charAllowed 0 && _tty_charAllowed 9 && ! _tty_charAllowed a && _tty_charAllowed $'\n'; then
        bts_pass "allow 0-9 drops letters, keeps enter"
    else
        bts_fail "charAllowed mismatch"
    fi

    tty_allow -p hex
    if _tty_charAllowed a && _tty_charAllowed F && ! _tty_charAllowed g; then
        bts_pass "tty_allow hex charset"
    else
        bts_fail "hex allow mismatch"
    fi

    tty_setPreset idle
    if [[ "${__TTY_POLICY}" == idle ]]; then
        bts_pass "preset idle"
    else
        bts_fail "idle policy=${__TTY_POLICY}"
    fi

    if tty_setPreset decimal && _tty_charAllowed . && _tty_charAllowed 3 && ! _tty_charAllowed a \
        && tty_setPreset hex && _tty_charAllowed a && _tty_charAllowed F && ! _tty_charAllowed g \
        && tty_setPreset cooked && [[ "${__TTY_POLICY}" == cooked ]] \
        && tty_setPreset hidden && [[ "${__TTY_POLICY}" == hidden ]] \
        && tty_setPreset cbreak && [[ "${__TTY_POLICY}" == cbreak ]]; then
        bts_pass "tty_setPreset decimal/hex/cooked/hidden/cbreak"
    else
        bts_fail "preset sweep policy=${__TTY_POLICY}"
    fi

    found=0
    if declare -p __EH_FUNC &>/dev/null; then
        for f in "${__EH_FUNC[@]}"; do
            [[ "$f" == tty_restore ]] && found=1
        done
    fi
    if (( found )); then
        bts_pass "tty_restore registered on exit"
    else
        bts_fail "tty_restore missing from event bus"
    fi

    rc=0
    _tty_isolated '
[[ "${__TTY_EXIT_PRIORITY}" == 7 ]] || exit 1
eventHas exit || exit 1
[[ "${ eventHookCount exit; }" -ge 1 ]] || exit 1
tty_restore
[[ "${__TTY_GUARD}" == 0 ]]
' || rc=$?
    if (( rc == 0 )); then
        bts_pass "init registers exit restore at TTY_EXIT_PRIORITY"
    else
        bts_fail "exit hook rc=$rc err=$(printf '%q' "${__TTY_ISOLATED_ERR}")"
    fi

    rc=0
    _tty_isolated '
tty_guardEnable
tty_restore
[[ "${__TTY_GUARD}" == 0 && "${__TTY_DEPTH}" == 0 ]]
' || rc=$?
    if (( rc == 0 )); then
        bts_pass "enable then restore clears guard"
    else
        bts_fail "enable/restore rc=$rc err=$(printf '%q' "${__TTY_ISOLATED_ERR}")"
    fi
}
