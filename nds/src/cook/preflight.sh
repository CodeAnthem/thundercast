#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook preflight
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Errors fail the run. Warnings are printed for the confirm screen.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_cook_preflight_warn_lines() {
    local -n _pre_R=$1
    local _pre_disk=${_pre_R[DISK_TARGET]:-} _pre_size _pre_parts
    if [[ ${_pre_R[INSTALL_MODE]:-} == remote ]]; then
        printf '%s\n' "The disk on ${_pre_R[REMOTE_TARGET_IP]:-the remote host} will be erased"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
            "root@${_pre_R[REMOTE_TARGET_IP]}" true 2>/dev/null; then
            printf '%s\n' "Cannot reach root@${_pre_R[REMOTE_TARGET_IP]} via SSH"
        fi
    elif [[ ${_pre_R[DISK_STRATEGY]:-nds} != flake ]]; then
        printf '%s\n' "${_pre_disk:-the target disk} — all data will be permanently erased"
    fi
    if [[ ${_pre_R[BOOT_UEFI_MODE]:-} == true && ! -d /sys/firmware/efi/efivars ]]; then
        printf '%s\n' "UEFI mode is on but this machine was booted as BIOS"
    fi
    if [[ -n "$_pre_disk" ]] && declare -f disk_canUse >/dev/null && disk_canUse "$_pre_disk"; then
        _pre_size=$(lsblk -bdno SIZE "$_pre_disk" 2>/dev/null || true)
        if [[ -n "$_pre_size" && "$_pre_size" -lt 17179869184 ]]; then
            printf '%s\n' "Disk ${_pre_disk} is smaller than 16G"
        fi
        _pre_parts=$(lsblk -ln "$_pre_disk" 2>/dev/null | wc -l)
        if [[ "${_pre_parts:-0}" -gt 1 ]]; then
            printf '%s\n' "Disk ${_pre_disk} already has partitions"
        fi
    fi
}

nds_cook_preflight_local() {
    local _pre_disk=${1:-} _pre_uefi=${2:-} _pre_loader=${3:-}
    command -v nix >/dev/null || { error "INSTALL_KIND: nix not found"; return 1; }
    command -v nixos-install >/dev/null || { error "INSTALL_KIND: nixos-install not found"; return 1; }
    if [[ -n "$_pre_disk" ]] && ! disk_canUse "$_pre_disk"; then
        error "DISK_TARGET: not found"
        return 1
    fi
    if [[ "$_pre_uefi" != true && "$_pre_loader" == systemd-boot ]]; then
        error "BOOT_LOADER: systemd-boot requires UEFI"
        return 1
    fi
    if [[ "$_pre_uefi" != true && "$_pre_loader" == refind ]]; then
        error "BOOT_LOADER: rEFInd requires UEFI"
        return 1
    fi
}

nds_cook_preflight_remote() {
    local _pre_ip=$1
    command -v nix >/dev/null || { error "INSTALL_KIND: nix not found"; return 1; }
    [[ -n "$_pre_ip" ]] || { error "REMOTE_TARGET_IP: required"; return 1; }
}

nds_cook_preflight() {
    local _pre_warn=0
    if [[ ${1:-} == --warnings ]]; then
        _pre_warn=1
        shift
    fi
    local -n _R=$1
    if (( _pre_warn )); then
        _nds_cook_preflight_warn_lines "$1"
        return 0
    fi
    [[ ${_R[INSTALL_KIND]:-} == classic || ${_R[INSTALL_KIND]:-} == flake ]] || {
        error "INSTALL_KIND: unsupported"
        return 1
    }
    if [[ ${_R[INSTALL_MODE]:-} == remote ]]; then
        nds_cook_preflight_remote "${_R[REMOTE_TARGET_IP]:-}" || return 1
    elif [[ ${_R[DISK_STRATEGY]:-nds} != flake ]]; then
        nds_cook_preflight_local "${_R[DISK_TARGET]:-}" "${_R[BOOT_UEFI_MODE]:-}" \
            "${_R[BOOT_LOADER]:-}" || return 1
    else
        command -v nix >/dev/null || { error "INSTALL_KIND: nix not found"; return 1; }
        command -v nixos-install >/dev/null || { error "INSTALL_KIND: nixos-install not found"; return 1; }
    fi
}
