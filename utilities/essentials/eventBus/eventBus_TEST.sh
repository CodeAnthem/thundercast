#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Event Bus tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-18
# ==================================================================================================
#
# eventRegister requires the hook function to already exist.
# Capture counts with `${ eventHookCount "$name"; }` (not $(...)).
# bts_section is for a sub-feature with several cases, not one box per assert.
#
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_eh_hook_a() { _EH_ORDER+=("a:$1"); }
_eh_hook_b() { _EH_ORDER+=("b:$1"); }
_eh_hook_stop() { _EH_ORDER+=("stop"); eventStop; }
_eh_hook_after() { _EH_ORDER+=("after"); }
_eh_hook_fail() { _EH_ORDER+=("fail"); return 1; }
_eh_hook_ok() { _EH_ORDER+=("ok"); return 0; }
_eh_hook_nested() {
    _EH_INNER=0
    eventRun test.eh.other || _EH_INNER=$?
    return 0
}

suite_eventBus() {
    local n rc
    essentials_test_load eventBus

    # --- Registry: priority, duplicate register, unregister ---------------------------------------
    bts_section "Registry"

    _EH_ORDER=()
    eventRegister test.eh.prio _eh_hook_b 50
    eventRegister test.eh.prio _eh_hook_a 10
    eventRun test.eh.prio "x"
    if [[ "${_EH_ORDER[*]}" == "a:x b:x" ]]; then
        bts_pass "lower priority runs first"
    else
        bts_fail "priority order was '${_EH_ORDER[*]}'"
    fi

    eventRegister test.eh.prio _eh_hook_a 99
    n=${ eventHookCount "test.eh.prio"; }
    _EH_ORDER=()
    eventRun test.eh.prio "x"
    if [[ "$n" == 2 && "${_EH_ORDER[*]}" == "a:x b:x" ]]; then
        bts_pass "duplicate register is a no-op"
    else
        bts_fail "dedupe count=$n order='${_EH_ORDER[*]}'"
    fi

    eventUnregister test.eh.prio _eh_hook_a
    n=${ eventHookCount "test.eh.prio"; }
    if [[ "$n" == 1 ]]; then
        bts_pass "unregister removes hook"
    else
        bts_fail "hook count after unregister was $n"
    fi
    eventUnregister test.eh.prio _eh_hook_b

    # --- Dispatch: eventStop vs non-zero abort ----------------------------------------------------
    bts_section "Dispatch stop"

    _EH_ORDER=()
    eventRegister test.eh.stop _eh_hook_stop 10
    eventRegister test.eh.stop _eh_hook_after 50
    rc=0
    eventRun test.eh.stop || rc=$?
    if [[ "$rc" -eq 0 && "${_EH_ORDER[*]}" == "stop" ]]; then
        bts_pass "eventStop skips remaining hooks"
    else
        bts_fail "eventStop rc=$rc order='${_EH_ORDER[*]}'"
    fi
    eventUnregister test.eh.stop _eh_hook_stop
    eventUnregister test.eh.stop _eh_hook_after

    _EH_ORDER=()
    eventRegister test.eh.abort _eh_hook_fail 10
    eventRegister test.eh.abort _eh_hook_after 50
    rc=0
    eventRun test.eh.abort || rc=$?
    if [[ "$rc" -eq 1 && "${_EH_ORDER[*]}" == "fail" ]]; then
        bts_pass "non-zero abort stops remaining hooks"
    else
        bts_fail "abort rc=$rc order='${_EH_ORDER[*]}'"
    fi
    eventUnregister test.eh.abort _eh_hook_fail
    eventUnregister test.eh.abort _eh_hook_after

    # --- Re-entrancy: nested rejected, sequential allowed -----------------------------------------
    bts_section "Re-entrancy"

    # stderr: expected "[ERROR] - [EventBus] - Re-entrant eventRun is not allowed"
    eventCreate test.eh.other
    eventRegister test.eh.nest _eh_hook_nested 50
    _EH_INNER=0
    eventRun test.eh.nest 2>/dev/null
    if [[ "$_EH_INNER" -ne 0 ]]; then
        bts_pass "nested eventRun is rejected"
    else
        bts_fail "nested eventRun was allowed"
    fi
    eventUnregister test.eh.nest _eh_hook_nested

    _EH_ORDER=()
    eventRegister test.eh.seq.a _eh_hook_a 50
    eventRegister test.eh.seq.b _eh_hook_b 50
    eventRun test.eh.seq.a "1"
    eventRun test.eh.seq.b "2"
    if [[ "${_EH_ORDER[*]}" == "a:1 b:2" ]]; then
        bts_pass "sequential eventRun works"
    else
        bts_fail "sequential order was '${_EH_ORDER[*]}'"
    fi
    eventUnregister test.eh.seq.a _eh_hook_a
    eventUnregister test.eh.seq.b _eh_hook_b

    # --- set -e: dispatch must not trip the shell on stop or abort --------------------------------
    bts_section "set -e"

    # `"$func" "$@" || rc=$?` so eventStop / hook abort stay in this shell.
    _EH_ORDER=()
    eventRegister test.eh.sete _eh_hook_ok 10
    eventRegister test.eh.sete _eh_hook_stop 20
    eventRegister test.eh.sete _eh_hook_after 50
    rc=0
    eventRun test.eh.sete || rc=$?
    if [[ "$rc" -eq 0 && "${_EH_ORDER[*]}" == "ok stop" ]]; then
        bts_pass "set -e survives eventStop"
    else
        bts_fail "set -e stop rc=$rc order='${_EH_ORDER[*]}'"
    fi
    eventUnregister test.eh.sete _eh_hook_ok
    eventUnregister test.eh.sete _eh_hook_stop
    eventUnregister test.eh.sete _eh_hook_after

    _EH_ORDER=()
    eventRegister test.eh.sete _eh_hook_fail 10
    eventRegister test.eh.sete _eh_hook_after 50
    rc=0
    eventRun test.eh.sete || rc=$?
    if [[ "$rc" -eq 1 && "${_EH_ORDER[*]}" == "fail" ]]; then
        bts_pass "set -e survives hook abort"
    else
        bts_fail "set -e abort rc=$rc order='${_EH_ORDER[*]}'"
    fi
    eventUnregister test.eh.sete _eh_hook_fail
    eventUnregister test.eh.sete _eh_hook_after
}
