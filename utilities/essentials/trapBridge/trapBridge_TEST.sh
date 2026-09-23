#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Trap Bridge tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_th_test_hook() { :; }

_th_exit_child() {
    local out="$1" mode="$2"
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
_essentials_test_ensureConfig
essentials_config[TRAP_PRESETS]=true
essentials_test_load trapBridge
OUT="$2"
MODE="$3"
_th_ex() { printf "exit:%s\n" "$1" >> "$OUT"; }
_th_err() { printf "exitError:%s\n" "$1" >> "$OUT"; }
_th_cl() { printf "exitClean:%s\n" "$1" >> "$OUT"; }
eventRegister exit _th_ex 50
eventRegister exitError _th_err 50
eventRegister exitClean _th_cl 50
case "$MODE" in
    clean) exit 0 ;;
    markerror) logger_markError; exit 0 ;;
    code) exit 2 ;;
esac
' _th_exit_child "$_ESSENTIALS_ROOT" "$out" "$mode"
}

suite_trapBridge() {
    local rc inner_trap child_out

    essentials_test_load trapBridge

    inner_trap="$(trap -p INT)"
    if [[ -z "$inner_trap" ]]; then
        bts_pass "INT trap absent before register"
    else
        bts_fail "INT trap already set: $inner_trap"
    fi

    trapRegister INT _th_test_hook
    inner_trap="$(trap -p INT)"
    if [[ "$inner_trap" == *_essentials_trapBridge_dispatch* ]]; then
        bts_pass "INT trap installed on first register"
    else
        bts_fail "INT trap after register: $inner_trap"
    fi

    _th_legacy() { :; }
    trap _th_legacy INT
    inner_trap="$(trap -p INT)"
    if [[ "$inner_trap" == *_th_legacy* ]]; then
        bts_pass "raw trap still last-wins"
    else
        bts_fail "raw trap did not replace dispatcher: $inner_trap"
    fi
    trapUnregister INT _th_test_hook 2>/dev/null || true
    trap - INT
    unset -f _th_legacy

    trapRegister INT _th_test_hook
    trapUnregister INT _th_test_hook
    inner_trap="$(trap -p INT)"
    if [[ -z "$inner_trap" ]]; then
        bts_pass "INT trap restored after last unregister"
    else
        bts_fail "INT trap after unregister: $inner_trap"
    fi

    child_out="$(mktemp)"
    rc=0
    bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
essentials_test_load trapBridge
OUT="$2"
_th_hit() { printf "hit\n" > "$OUT"; }
trapRegister INT _th_hit
kill -INT $$
' _th_int_child "$_ESSENTIALS_ROOT" "$child_out" || rc=$?
    if [[ "$rc" -eq 0 && "$(<"$child_out")" == "hit" ]]; then
        bts_pass "INT dispatcher runs registered hook"
    else
        bts_fail "INT dispatcher rc=$rc out=$(printf '%q' "$(<"$child_out" 2>/dev/null || true)")"
    fi
    rm -f "$child_out"

    child_out="$(mktemp)"
    _th_exit_child "$child_out" clean
    if [[ "$(<"$child_out")" == $'exit:0\nexitClean:0' ]]; then
        bts_pass "EXIT clean path"
    else
        bts_fail "EXIT clean was $(printf '%q' "$(<"$child_out")")"
    fi
    : >"$child_out"
    _th_exit_child "$child_out" markerror
    if [[ "$(<"$child_out")" == $'exit:0\nexitError:0' ]]; then
        bts_pass "EXIT error path from logger_markError"
    else
        bts_fail "EXIT markerror was $(printf '%q' "$(<"$child_out")")"
    fi
    : >"$child_out"
    rc=0
    _th_exit_child "$child_out" code || rc=$?
    if [[ "$rc" -eq 2 && "$(<"$child_out")" == $'exit:2\nexitError:2' ]]; then
        bts_pass "EXIT error path from non-zero status"
    else
        bts_fail "EXIT code rc=$rc was $(printf '%q' "$(<"$child_out")")"
    fi
    rm -f "$child_out"
}
