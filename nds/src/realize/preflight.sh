#!/usr/bin/env bash
# ==================================================================================================
# NDS - Realize preflight
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Errors fail the run. Warnings are recorded for the confirm screen.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_realize_preflight() {
    local _pre_warn=0
    if [[ ${1:-} == --warnings ]]; then
        _pre_warn=1
        shift
    fi
    local -n _R=$1
    if (( _pre_warn )); then
        if [[ ${_R[INSTALL_MODE]:-} == remote ]]; then
            printf '%s\n' "The disk on ${_R[REMOTE_TARGET_IP]:-the remote host} will be erased"
        elif [[ ${_R[DISK_STRATEGY]:-nds} != flake ]]; then
            printf '%s\n' "${_R[DISK_TARGET]:-the target disk} — all data will be permanently erased"
        fi
        return 0
    fi
    [[ ${_R[INSTALL_KIND]:-} == classic || ${_R[INSTALL_KIND]:-} == flake ]] || {
        error "INSTALL_KIND: unsupported"
        return 1
    }
    if [[ ${_R[INSTALL_MODE]:-} == remote && -z ${_R[REMOTE_TARGET_IP]:-} ]]; then
        error "REMOTE_TARGET_IP: required"
        return 1
    fi
    return 0
}
