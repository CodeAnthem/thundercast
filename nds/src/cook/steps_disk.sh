#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook disk step
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Unmount, space check, partition or disko, mount, initrd key copy.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_NDS_STEP_DISK_AA=

_step_luksFormat() {
    local -n _step_disk_R=${_NDS_STEP_DISK_AA}
    disk_luksFormat "$1" "${_step_disk_R[ENCRYPTION_PASSPHRASE_FILE]:-}" \
        "${_step_disk_R[ENCRYPTION_KEY_FILE]:-}"
}

step_disk() {
    local -n _R=$1
    local _disk_strategy=${_R[DISK_STRATEGY]:-nds}
    local _disk_target=${_R[DISK_TARGET]:-}
    local _disk_unlock=manual
    _NDS_STEP_DISK_AA=$1
    if [[ "$_disk_strategy" == flake ]]; then
        mountpoint -q "$_NDS_TARGET_ROOT" || {
            error "DISK_STRATEGY: ${_NDS_TARGET_ROOT} is not mounted"
            return 1
        }
        return 0
    fi
    disk_unmountTarget "$_NDS_TARGET_ROOT" || return 1
    nixos_ensureLiveStoreSpace 64 || return 1
    if [[ "$_disk_strategy" == disko ]]; then
        if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_KEY]:-} == true && ${_R[ENCRYPTION_PASSWORD]:-} != true ]]; then
            _disk_unlock=keyfile
        fi
        disk_diskoApply "$_disk_target" \
            "${_R[DISK_FS_TYPE]:-}" "${_R[DISK_SWAP_SIZE_MIB]:-}" \
            "" "" \
            "${_R[ENCRYPTION]:-false}" "$_disk_unlock" \
            "${_R[DISK_DISKO_CONFIG]:-}" "${_R[BOOT_LOADER]:-systemd-boot}" \
            "${ nds_session_dir work; }/disko" || return 1
    elif [[ ${_R[ENCRYPTION]:-} == true ]]; then
        disk_partition "$_disk_target" true "${_R[BOOT_UEFI_MODE]:-}" _step_luksFormat || return 1
        disk_mountRoot true "$_NDS_TARGET_ROOT" || return 1
    else
        disk_partition "$_disk_target" false "${_R[BOOT_UEFI_MODE]:-}" || return 1
        disk_mountRoot false "$_NDS_TARGET_ROOT" || return 1
    fi
    if [[ ${_R[ENCRYPTION]:-} == true && ${_R[ENCRYPTION_REMOTE_UNLOCK]:-} == true \
        && -n ${_R[ENCRYPTION_REMOTE_HOSTKEY_FILE]:-} ]]; then
        disk_setupInitrdSshKeys "$_NDS_TARGET_ROOT" "${_R[ENCRYPTION_REMOTE_HOSTKEY_FILE]}" || return 1
    fi
}
