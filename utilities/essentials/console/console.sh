#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Console
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-27 | Modified: 2026-09-27
# Description:   Finished stdout and stderr lines that yield an open task, then resume it.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_console_init() {
    _essentials_init_isDone console && return 0
    _essentials_init_mark console
}
_essentials_console_init || return 1

# fd 2 yields around an open task. fd 1 yields only when stdout is a terminal.
_essentials_console_emit() {
    local fd=$1 line=$2
    local yield=false
    if [[ "$fd" -eq 2 ]]; then
        yield=true
    elif [[ -t 1 ]]; then
        yield=true
    fi
    if [[ "$yield" == true ]] && declare -f taskYield >/dev/null && declare -f taskIsOpen >/dev/null && taskIsOpen; then
        taskYield || true
        printf '%s\n' "$line" >&"$fd" || return 1
        taskResume || true
        return 0
    fi
    printf '%s\n' "$line" >&"$fd"
}

console_writeErr() { _essentials_console_emit 2 "$1"; }
console_writeOut() { _essentials_console_emit 1 "$1"; }
