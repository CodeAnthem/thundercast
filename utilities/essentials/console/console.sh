#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Console
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-27 | Modified: 2026-09-27
# Description:   One finished console line that yields an open task, then resumes it.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_console_init() {
    _essentials_init_isDone console && return 0
    local -n config="essentials_config"
    local stream="${config[CONSOLE_STREAM]:-stderr}"
    case "$stream" in
        stdout|stderr) ;;
        *) error "Console: invalid CONSOLE_STREAM: ${stream}"; return 1 ;;
    esac
    declare -g __CONSOLE_STREAM="$stream"
    _essentials_init_mark console
}
_essentials_console_init || return 1

# Print one finished line. Yield an open task around that line.
console_write() {
    local line="$1" fd=2
    [[ "$__CONSOLE_STREAM" == stdout ]] && fd=1
    if declare -f taskYield >/dev/null && declare -f taskIsOpen >/dev/null && taskIsOpen; then
        taskYield || true
        printf '%s\n' "$line" >&"$fd" || return 1
        taskResume || true
        return 0
    fi
    printf '%s\n' "$line" >&"$fd"
}
