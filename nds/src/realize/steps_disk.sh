#!/usr/bin/env bash
# ==================================================================================================
# NDS - Realize disk step
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

step_disk() {
    local -n _R=$1
    local _disk_strategy=${_R[DISK_STRATEGY]:-nds}
    local _disk_target=${_R[DISK_TARGET]:-}
    if [[ "$_disk_strategy" == flake ]]; then
        mountpoint -q /mnt || {
            error "DISK_STRATEGY: /mnt is not mounted"
            return 1
        }
        return 0
    fi
    disk_unmountTarget /mnt || return 1
    disk_canUse "$_disk_target" || return 1
    if [[ ${_R[ENCRYPTION]:-} == true ]]; then
        disk_luksFormat "$_disk_target" "${_R[ENCRYPTION_PASSPHRASE_FILE]:-}" \
            "${_R[ENCRYPTION_KEY_FILE]:-}" || return 1
    fi
    if [[ "$_disk_strategy" == disko ]]; then
        disk_diskoApply "$_disk_target" || return 1
    else
        disk_partition "$_disk_target" || return 1
    fi
    disk_mountRoot /mnt || return 1
    if [[ ${_R[ENCRYPTION_REMOTE_UNLOCK]:-} == true && -n ${_R[ENCRYPTION_REMOTE_HOSTKEY_FILE]:-} ]]; then
        disk_setupInitrdSshKeys /mnt "${_R[ENCRYPTION_REMOTE_HOSTKEY_FILE]}" || return 1
    fi
}
