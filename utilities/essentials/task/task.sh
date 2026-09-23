#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Task
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-20
# ==================================================================================================
#
# Progress chrome: in-progress line, spinner, OK/FAIL. Vacates the CR line on
# ui.line.take. Open task is a bug on ui.section.begin.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_task_init() {
    [[ "${__TASK_INITIALIZED:-false}" == true ]] && return 0

    declare -g __TASK_NAME=""
    declare -g __TASK_START=0
    declare -g __TASK_SPIN_PID=""
    declare -g __TASK_WANT_SPIN=0

    if declare -f eventRegister &>/dev/null; then
        eventRegister ui.line.take taskYield || return 1
        eventRegister ui.section.begin _taskOnSectionBegin || return 1
        eventRegister trap.INT taskOnInt 10 || return 1
    fi

    declare -g __TASK_INITIALIZED=true
}

_taskTty() {
    if declare -f tty_ok &>/dev/null; then
        tty_ok
    else
        [[ -t 2 ]]
    fi
}

_taskIcon() {
    local state="$1"
    case "$state" in
        start)
            printf '[   ]'
            ;;
        ok)
            if [[ "${__UI_COLOR:-false}" == true ]] && _taskTty; then
                printf '\033[32m[OK]\033[0m'
            else
                printf '[OK]'
            fi
            ;;
        fail)
            if [[ "${__UI_COLOR:-false}" == true ]] && _taskTty; then
                printf '\033[31m[FAIL]\033[0m'
            else
                printf '[FAIL]'
            fi
            ;;
    esac
}

# Empty children file → read EOF 1. Must not abort under set -e (INT/EXIT).
_taskKillPidTree() {
    local pid="$1" child
    local -a kids=()
    [[ -n "$pid" ]] || return 0
    if [[ -r "/proc/${pid}/task/${pid}/children" ]]; then
        read -ra kids < "/proc/${pid}/task/${pid}/children" || true
    fi
    for child in "${kids[@]}"; do
        _taskKillPidTree "$child" || true
    done
    kill "$pid" 2>/dev/null || true
}

_taskSpinnerStop() {
    local pid="${__TASK_SPIN_PID:-}"
    [[ -n "$pid" ]] || return 0
    _taskKillPidTree "$pid"
    kill -KILL "$pid" 2>/dev/null || true
    _taskKillPidTree "$pid"
    wait "$pid" 2>/dev/null || true
    if [[ "${__TASK_SPIN_PID:-}" == "$pid" ]]; then
        __TASK_SPIN_PID=""
    fi
}

# Background spinner. Async children ignore SIGINT — parent must kill (taskOnInt).
_taskSpinnerStart() {
    local message="$1"
    _taskSpinnerStop
    _taskTty || return 0
    (
        trap 'exit 0' TERM HUP INT
        local spinstr='|/-\\' char
        while true; do
            char="${spinstr:0:1}"
            printf '\r\033[K%s[%s%s] %s' "${__UI_INDENT_B:-  }" "$char" "$char" "$message" >&2
            spinstr="${spinstr:1}${spinstr:0:1}"
            sleep 0.12
        done
    ) </dev/null &
    __TASK_SPIN_PID=$!
}

_taskElapsed() {
    local now=0 start="${__TASK_START:-0}"
    printf -v now '%(%s)T' -1
    [[ "$start" =~ ^[1-9][0-9]*$ ]] || { printf 0; return 0; }
    printf '%s' "$((now - start))"
}

_taskClear() {
    __TASK_NAME=""
    __TASK_START=0
    __TASK_WANT_SPIN=0
}

# Clear the in-progress task line so other TTY output can print.
taskYield() {
    [[ -n "${__TASK_NAME:-}" ]] || return 0
    _taskSpinnerStop
    _taskTty || return 0
    printf '\r\033[K' >&2
}

# Re-draw the in-progress task after yielded TTY output.
taskResume() {
    [[ -n "${__TASK_NAME:-}" ]] || return 0
    _taskTty || return 0
    if [[ "${__TASK_WANT_SPIN}" == 1 ]]; then
        _taskSpinnerStart "$__TASK_NAME"
        return 0
    fi
    printf '%s%s %s' "${__UI_INDENT_B:-  }" "${ _taskIcon start; }" "$__TASK_NAME" >&2
}

# Start an in-progress task line on stderr.
taskStart() {
    local message="$1"
    _taskSpinnerStop
    __TASK_WANT_SPIN=0
    __TASK_NAME="$message"
    printf -v __TASK_START '%(%s)T' -1
    _taskTty || return 0
    printf '%s%s %s' "${__UI_INDENT_B:-  }" "${ _taskIcon start; }" "$message" >&2
}

# Start a task and animate until ok, fail, or cancel.
# Background spinner: caller does the work in this shell. Kill on INT (taskOnInt).
taskSpin() {
    taskStart "$1"
    __TASK_WANT_SPIN=1
    _taskSpinnerStart "$1"
}

# Foreground spinner until <pid> exits. Ctrl+C hits this shell.
taskWatch() {
    local pid="$1" message="${2:-$__TASK_NAME}"
    local spinstr='|/-\\' char
    [[ -n "$pid" ]] || return 1
    _taskTty || {
        while kill -0 "$pid" 2>/dev/null; do
            sleep 0.12
        done
        return 0
    }
    while kill -0 "$pid" 2>/dev/null; do
        char="${spinstr:0:1}"
        printf '\r\033[K%s[%s%s] %s' "${__UI_INDENT_B:-  }" "$char" "$char" "$message" >&2
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep 0.12
    done
}

# Drop the in-progress task without OK/FAIL. Caller must do this before ui_section.
taskCancel() {
    _taskSpinnerStop
    if _taskTty && [[ -n "${__TASK_NAME:-}" ]]; then
        printf '\r\033[K' >&2
    fi
    _taskClear
}

# Finish the current task as success.
taskOk() {
    local message="${1:-$__TASK_NAME}" elapsed
    elapsed=${ _taskElapsed; }
    _taskSpinnerStop
    if _taskTty; then
        printf '\r\033[K%s%s %s  (%ds)\n' "${__UI_INDENT_B:-  }" "${ _taskIcon ok; }" "$message" "$elapsed" >&2
    else
        printf '%s[OK] %s  (%ds)\n' "${__UI_INDENT_B:-  }" "$message" "$elapsed" >&2
    fi
    _taskClear
}

# Finish the current task as failure.
taskFail() {
    local message="${1:-$__TASK_NAME}" elapsed
    elapsed=${ _taskElapsed; }
    _taskSpinnerStop
    if _taskTty; then
        printf '\r\033[K%s%s %s  (%ds)\n' "${__UI_INDENT_B:-  }" "${ _taskIcon fail; }" "$message" "$elapsed" >&2
    else
        printf '%s[FAIL] %s  (%ds)\n' "${__UI_INDENT_B:-  }" "$message" "$elapsed" >&2
    fi
    _taskClear
}

# Open task on ui.section.begin: fail it, then fatal. Hook must return 0 if idle.
_taskOnSectionBegin() {
    local name="${__TASK_NAME:-}"
    [[ -n "$name" ]] || return 0
    taskFail "$name"
    if declare -f fatal &>/dev/null; then
        fatal "step: ui.section.begin while open (${name})"
    fi
    echo "[ERROR] - [step] - ui.section.begin while open (${name}); close it with taskOk, taskFail, or taskCancel" >&2
    return 1
}

# Cancel the task, then abort. EXIT restores the TTY. Register: trapRegister INT taskOnInt.
taskOnInt() {
    taskCancel
    printf '\n' >&2
    exit 130
}

_essentials_task_init || return 1
