#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Task tests
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-20 | Modified: 2026-09-20
# ==================================================================================================

# shellcheck source=../testEnvironment/testEnvironment.sh
source "$(dirname "${BASH_SOURCE[0]}")/../testEnvironment/testEnvironment.sh"

_task_isolated() {
    local rc=0
    __TASK_ISOLATED_ERR=""
    __TASK_ISOLATED_ERR=$(
        bash -c '
set -euo pipefail
source "$1/testEnvironment/testEnvironment.sh"
essentials_test_load task
eval "$2"
' _task_iso "$_ESSENTIALS_ROOT" "$1" 2>&1
    ) || rc=$?
    return "$rc"
}

suite_task() {
    local rc tmp

    essentials_test_load task

    tmp=$(mktemp)
    {
        taskStart "work"
        taskOk "work"
    } 2>"$tmp"
    if grep -q '\[OK\] work' "$tmp"; then
        bts_pass "task ok without TTY"
    else
        bts_fail "task output $(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    tmp=$(mktemp)
    {
        __TASK_NAME="x"
        __TASK_START=0
        taskOk "x"
    } 2>"$tmp"
    if grep -q '(0s)' "$tmp" && ! grep -qE '\([1-9][0-9]{8,}s\)' "$tmp"; then
        bts_pass "task ok without start is 0s"
    else
        bts_fail "stray task elapsed $(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    tmp=$(mktemp)
    {
        taskStart "ok-then-section"
        taskOk
        ui_section "next"
    } 2>"$tmp" || rc=$?
    if (( rc == 0 )) && grep -q '\[OK\]' "$tmp" && grep -q 'next' "$tmp"; then
        bts_pass "section after taskOk"
    else
        bts_fail "section after ok rc=$rc out=$(printf '%q' "$(<"$tmp")")"
    fi
    rm -f "$tmp"

    rc=0
    _task_isolated '
taskStart "hanging"
ui_section "next"
' || rc=$?
    if (( rc != 0 )) && [[ "${__TASK_ISOLATED_ERR}" == *'[FAIL] hanging'* ]] && [[ "${__TASK_ISOLATED_ERR}" == *'ui.section.begin while open'* ]]; then
        bts_pass "section with open task fails the task and dies"
    else
        bts_fail "open-task section rc=$rc err=$(printf '%q' "${__TASK_ISOLATED_ERR}")"
    fi

    rc=0
    tmp=$(mktemp)
    taskStart "hanging" 2>"$tmp"
    eventRun ui.line.take 2>>"$tmp" || true
    if [[ "$__TASK_NAME" == hanging ]]; then
        bts_pass "line.take keeps task name"
    else
        bts_fail "line.take name=${__TASK_NAME}"
    fi
    taskCancel
    rm -f "$tmp"

    rc=0
    _task_isolated '
set -euo pipefail
bash -c "sleep 30" &
pid=$!
sleep 0.05
_taskKillPidTree "$pid"
kill -KILL "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
if kill -0 "$pid" 2>/dev/null; then
    exit 1
fi
' || rc=$?
    if (( rc == 0 )); then
        bts_pass "killPidTree survives empty children under set -e"
    else
        bts_fail "killPidTree rc=$rc err=$(printf '%q' "${__TASK_ISOLATED_ERR}")"
    fi
}
