#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Bash Essentials - Root Reexec
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-12 | Modified: 2026-09-24
# Description:   Re-executes the process as root via sudo when ROOTREEXEC_ROOT is true.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_essentials_rootReexec_collectEnv() {
    local -n out="$1"
    local keep_prefix="$2"
    local keep_vars="$3"
    local name
    local -a _rr_names=()

    if [[ -n "$keep_prefix" ]]; then
        [[ "$keep_prefix" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
            || fatal "RootReexec: invalid ROOTREEXEC_KEEP_ENV_PREFIX: ${keep_prefix}"
        eval "for name in \${!${keep_prefix}@}; do out+=(\"\$name=\${!name}\"); done"
    fi

    if [[ -n "$keep_vars" ]]; then
        read -ra _rr_names <<< "$keep_vars"
        for name in "${_rr_names[@]}"; do
            [[ -n "$name" && -n "${!name+x}" ]] && out+=("$name=${!name}")
        done
    fi
}

_essentials_rootReexec_init() {
    _essentials_init_isDone rootReexec && return 0
    _essentials_init_mark rootReexec

    local -n config="essentials_config"
    [[ $EUID -eq 0 ]] && return 0
    [[ "${config[ROOTREEXEC_ROOT]:-false}" == "true" ]] || { debug "RootReexec: root re-exec disabled, skipping"; return 0; }

    local -n scriptArgs="originalArgs"
    local script_path="${config[ROOTREEXEC_SCRIPT]:-}"
    local purpose="${config[ROOTREEXEC_PURPOSE]:-}"
    [[ -n "$script_path" ]] || fatal "RootReexec: ROOTREEXEC_SCRIPT is required when ROOTREEXEC_ROOT is enabled"
    [[ -f "$script_path" ]] || fatal "RootReexec: script not found: ${script_path}"
    command -v sudo &>/dev/null || fatal "RootReexec: sudo is not available"

    local -a preserve_vars=()
    _essentials_rootReexec_collectEnv preserve_vars \
        "${config[ROOTREEXEC_KEEP_ENV_PREFIX]:-}" \
        "${config[ROOTREEXEC_KEEP_ENV_VARS]:-}"

    info "Root required${purpose:+ for ${purpose}} — re-running via sudo."
    exec sudo ${preserve_vars[@]+"${preserve_vars[@]}"} bash "$script_path" "${scriptArgs[@]}"
}

_essentials_rootReexec_init || return 1
