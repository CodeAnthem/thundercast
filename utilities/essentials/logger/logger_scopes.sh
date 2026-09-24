#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Logger Scopes
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-09-24
# Description:   Named log files under LOG_ROOT, and which scope is current.
# ==================================================================================================

# Block Script Execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

# States
declare -g __LOGGER_SCOPE_CURRENT="${__LOGGER_SCOPE_CURRENT:-}"
declare -gA __LOGGER_SCOPE_TITLES=()
declare -gA __LOGGER_SCOPE_PATHS=()

# Initialize Logger Scopes
_essentials_logger_scopes_init() {
    local rootDir=$1
    [[ -z "$rootDir" ]] && { echo "[ERROR] - [Logger] - Root directory is required" >&2; return 1; }

    local doPurge="$2"
    if [[ -d "$rootDir" ]]; then
        if [[ "$doPurge" != false ]]; then
            rm -f -- "$rootDir"/*.log
        fi
    else
        mkdir -p -- "$rootDir" || return 1
    fi
    declare -g __LOGGER_SCOPE_ROOT="$rootDir"

    logger_scopeCreate "All Logs" "all"
}

_essentials_logger_scope_sanitize() {
    local input="${1,,}"

    input="${input//[^a-z0-9._-]/_}"
    while [[ "$input" == *"__"* ]]; do
        input="${input//__/_}"
    done
    input="${input##_}"
    input="${input%_}"

    printf -v "$2" '%s' "$input"
}

logger_scopeExists() {
    [[ -n "${1:-}" ]] && [[ -n "${__LOGGER_SCOPE_PATHS[$1]+_}" ]]
}

_essentials_logger_scope_require() {
    local scope=${1:-}
    [[ -n "$scope" ]] || { echo "[ERROR] - [Logger] - Scope is required" >&2; return 1; }
    [[ -n "${__LOGGER_SCOPE_PATHS[$scope]+_}" ]] || { echo "[ERROR] - [Logger] - Scope '$scope' does not exist" >&2; return 1; }
}

logger_scopeCreate() {
    local title=${1:-}
    local scope=${2:-}
    local filename=${3:-}

    [[ -n "${__LOGGER_SCOPE_ROOT:-}" ]] || { echo "[ERROR] - [Logger] - Root directory is not initialized" >&2; return 1; }

    _essentials_logger_scope_sanitize "$scope" scope
    [[ -n "$scope" ]] || { echo "[ERROR] - [Logger] - Scope name argument '2' is required" >&2; return 1; }
    [[ -z "${__LOGGER_SCOPE_PATHS[$scope]+_}" ]] || { echo "[ERROR] - [Logger] - Scope '$scope' already exists" >&2; return 1; }

    [[ -n "$filename" ]] || filename="${scope}.log"
    _essentials_logger_scope_sanitize "$filename" filename
    [[ -n "$filename" ]] || { echo "[ERROR] - [Logger] - Scope filename is required" >&2; return 1; }

    __LOGGER_SCOPE_TITLES["$scope"]="$title"
    __LOGGER_SCOPE_PATHS["$scope"]="${__LOGGER_SCOPE_ROOT}/${filename}"
    __LOGGER_SCOPE_CURRENT="$scope"
    if [[ "$scope" == "all" ]]; then
        declare -g __LOGGER_SCOPE_ALL_PATH="${__LOGGER_SCOPE_PATHS[$scope]}"
    fi

    touch -- "${__LOGGER_SCOPE_PATHS[$scope]}" || { echo "[ERROR] - [Logger] - Failed to create scope file '$scope'" >&2; return 1; }
}

logger_scopeSet() {
    local scope=${1:-}
    _essentials_logger_scope_require "$scope" || return 1
    __LOGGER_SCOPE_CURRENT="$scope"
}

logger_scopeGetCurrent() {
    printf '%s\n' "${__LOGGER_SCOPE_CURRENT:-}"
}

logger_scopeGetPath() {
    local scope=${1:-${__LOGGER_SCOPE_CURRENT:-}}
    _essentials_logger_scope_require "$scope" || return 1

    printf '%s\n' "${__LOGGER_SCOPE_PATHS[$scope]}"
}

logger_scopeGetTitle() {
    local scope=${1:-${__LOGGER_SCOPE_CURRENT:-}}
    _essentials_logger_scope_require "$scope" || return 1

    printf '%s\n' "${__LOGGER_SCOPE_TITLES[$scope]}"
}

_essentials_logger_scope_write() {
    local message=${1:-}
    local scope=${2:-${__LOGGER_SCOPE_CURRENT:-}}
    _essentials_logger_scope_require "$scope" || return 1
    [[ -n "${__LOGGER_SCOPE_ALL_PATH:-}" ]] || { echo "[ERROR] - [Logger] - All-logs path is not initialized" >&2; return 1; }

    printf '%s\n' "$message" >> "${__LOGGER_SCOPE_PATHS[$scope]}"
    printf '%s\n' "$message" >> "$__LOGGER_SCOPE_ALL_PATH"
}

logger_scopeRead() {
    local scope=${1:-${__LOGGER_SCOPE_CURRENT:-}}
    local lines=${2:-0}
    _essentials_logger_scope_require "$scope" || return 1

    if (( lines == 0 )); then
        cat -- "${__LOGGER_SCOPE_PATHS[$scope]}"
        return 0
    fi

    if (( lines > 0 )); then
        head -n "$lines" -- "${__LOGGER_SCOPE_PATHS[$scope]}"
    else
        tail -n "$lines" -- "${__LOGGER_SCOPE_PATHS[$scope]}"
    fi
}
