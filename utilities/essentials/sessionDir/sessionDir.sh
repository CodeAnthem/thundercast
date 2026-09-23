#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Session Dir
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-17 | Modified: 2026-09-17
# ==================================================================================================
#
# Session scratch directory. No event hooks — caller purges.
#
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g __RUNTIME_DIR=""
declare -gA __RUNTIME_SUBDIRS=()

_essentials_sessionDir_sanitize() {
    local input="${1,,}"
    input="${input//[^a-z0-9._-]/_}"
    while [[ "$input" == *"__"* ]]; do
        input="${input//__/_}"
    done
    input="${input##_}"
    input="${input%_}"
    printf -v "$2" '%s' "$input"
}

_essentials_sessionDir_requireDir() {
    [[ -n "${__RUNTIME_DIR:-}" && -d "${__RUNTIME_DIR}" ]] || {
        echo "[ERROR] - [SessionDir] - Root directory is not initialized" >&2
        return 1
    }
}

# mkdir + chmod as the current user. Cannot apply → fatal (does not escalate).
_essentials_sessionDir_prepareDir() {
    local path="$1"
    mkdir -p -- "$path" \
        || fatal "SessionDir: cannot create ${path}"
    chmod -- "${__RUNTIME_MODE}" "$path" \
        || fatal "SessionDir: cannot chmod ${__RUNTIME_MODE} on ${path} (requires root)"
}

_essentials_sessionDir_purgeStale() {
    local base="$1" prefix="$2" d removed=0
    local _rt_ng
    _rt_ng=${ shopt -p nullglob; }
    shopt -s nullglob
    for d in "${base}/${prefix}_"*; do
        [[ -d "$d" ]] || continue
        rm -rf -- "$d" && removed=$((removed + 1)) || true
    done
    eval "${_rt_ng}"
    (( removed > 0 )) && info "SessionDir: removed ${removed} stale dir(s) under ${base}"
    return 0
}

# Print the session directory.
runtime_getDir() {
    _essentials_sessionDir_requireDir || return 1
    printf '%s\n' "$__RUNTIME_DIR"
}

# True if a tracked subdir exists.
runtime_hasSubdir() {
    local name=""
    _essentials_sessionDir_sanitize "${1:-}" name
    [[ -n "$name" && -n "${__RUNTIME_SUBDIRS[$name]+_}" ]]
}

# Print a tracked subdir path.
runtime_getPath() {
    local name=""
    _essentials_sessionDir_requireDir || return 1
    _essentials_sessionDir_sanitize "${1:-}" name
    [[ -n "$name" && -n "${__RUNTIME_SUBDIRS[$name]+_}" ]] || {
        echo "[ERROR] - [SessionDir] - Unknown subdir: ${1:-}" >&2
        return 1
    }
    printf '%s\n' "${__RUNTIME_SUBDIRS[$name]}"
}

# Create and track a subdir.
runtime_subdirCreate() {
    local name="" path
    _essentials_sessionDir_requireDir || return 1
    _essentials_sessionDir_sanitize "${1:-}" name
    [[ -n "$name" ]] || { echo "[ERROR] - [SessionDir] - Subdir name is required" >&2; return 1; }
    [[ -z "${__RUNTIME_SUBDIRS[$name]+_}" ]] || {
        echo "[ERROR] - [SessionDir] - Subdir already exists: ${name}" >&2
        return 1
    }
    path="${__RUNTIME_DIR}/${name}"
    _essentials_sessionDir_prepareDir "$path"
    __RUNTIME_SUBDIRS[$name]="$path"
}

# Remove tracked subdirs. Unknown names are skipped.
runtime_purge() {
    local raw name path
    (($# >= 1)) || { echo "[ERROR] - [SessionDir] - Subdir name required" >&2; return 1; }
    _essentials_sessionDir_requireDir || return 1
    for raw in "$@"; do
        name=""
        _essentials_sessionDir_sanitize "$raw" name
        [[ -n "$name" && -n "${__RUNTIME_SUBDIRS[$name]+_}" ]] || continue
        path="${__RUNTIME_SUBDIRS[$name]}"
        rm -rf -- "$path" || { warn "SessionDir: failed to remove ${name}"; return 1; }
        unset "__RUNTIME_SUBDIRS[$name]"
    done
    return 0
}

# Remove the session directory and all subdirs.
runtime_purgeAll() {
    if [[ -n "${__RUNTIME_DIR:-}" && -d "${__RUNTIME_DIR}" ]]; then
        rm -rf -- "$__RUNTIME_DIR" || { warn "SessionDir: failed to remove ${__RUNTIME_DIR}"; return 1; }
    fi
    __RUNTIME_DIR=""
    __RUNTIME_SUBDIRS=()
    return 0
}

_essentials_sessionDir_init() {
    _essentials_init_isDone sessionDir && return 0

    local -n config="essentials_config"
    local base="${config[RUNTIME_BASE]:-${TMPDIR:-/tmp}}"
    local prefix="" mode="${config[RUNTIME_MODE]:-700}"
    local timestamp="" name
    local -a _rt_subs=()

    _essentials_sessionDir_sanitize "${config[RUNTIME_PREFIX]:-essentials}" prefix
    [[ -n "$prefix" ]] || fatal "SessionDir: RUNTIME_PREFIX is required"
    [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fatal "SessionDir: invalid RUNTIME_MODE: ${mode}"

    mkdir -p -- "$base" \
        || fatal "SessionDir: cannot create base ${base}"
    [[ "${config[RUNTIME_PURGE_STALE]:-false}" == true ]] && _essentials_sessionDir_purgeStale "$base" "$prefix"

    printf -v timestamp '%(%Y%m%d_%H%M%S)T' -1
    [[ -n "$timestamp" ]] || return 1

    declare -g __RUNTIME_MODE="$mode"
    __RUNTIME_DIR="${base}/${prefix}_${timestamp}_$$"
    _essentials_sessionDir_prepareDir "$__RUNTIME_DIR"

    if [[ -n "${config[RUNTIME_SUBDIRS]:-}" ]]; then
        read -ra _rt_subs <<< "${config[RUNTIME_SUBDIRS]}"
        for name in "${_rt_subs[@]}"; do
            [[ -n "$name" ]] || continue
            runtime_hasSubdir "$name" && continue
            runtime_subdirCreate "$name" || return 1
        done
    fi

    _essentials_init_mark sessionDir
}
_essentials_sessionDir_init || return 1
