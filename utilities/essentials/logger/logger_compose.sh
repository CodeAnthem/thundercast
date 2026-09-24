#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger Compose
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# Description:   Merges selected scope files into one compose file as titled sections.
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# Initialize Logger Compose
_essentials_logger_compose_init() { logger_scopeCreate "Compose Log" "internal_compose" "$1"; }

logger_composeWrite() { _essentials_logger_output log "$1" file internal_compose; }

_essentials_logger_compose_section() {
    local scope=$1
    local path=${__LOGGER_SCOPE_PATHS[$scope]:-}
    [[ -n "$path" ]] || return 0

    printf '\n%s\n%s\n%s\n' \
        "--------------------------------------------------------------------------------" \
        "${__LOGGER_SCOPE_TITLES[$scope]:-$scope}" \
        "--------------------------------------------------------------------------------"
    if [[ -s "$path" ]]; then
        cat -- "$path"
    else
        printf '%s\n' "(empty)"
    fi
}

# Missing / unknown scopes are skipped (not an error).
logger_compose() {
    local title=$1
    shift 1 || true

    local composeFile="${__LOGGER_SCOPE_PATHS[internal_compose]:-}"
    [[ -n "$composeFile" ]] || { echo "[ERROR] - [Logger] - Compose file not found" >&2; return 1; }

    {
        if [[ ! -s "$composeFile" ]]; then
            printf '%s\n' "================================================================================"
            printf '%s\n' " $title"
            printf '%s\n' "================================================================================"
        fi

        local scope
        for scope in "$@"; do
            [[ "$scope" == "internal_compose" ]] && continue
            logger_scopeExists "$scope" || continue
            _essentials_logger_compose_section "$scope"
        done
    } >>"$composeFile"
}

logger_composeRead() {
    local lines=${1:-0}
    logger_scopeRead "internal_compose" "$lines"
}
