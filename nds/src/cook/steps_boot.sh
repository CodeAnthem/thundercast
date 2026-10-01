#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook bootloader registration
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-29
# Description:   UEFI registers the firmware entry. BIOS is a no-op; nixos-install wrote GRUB.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

step_bootloader() {
    local -n _R=$1
    local _efi_path
    [[ ${_R[BOOT_UEFI_MODE]:-} == true ]] || return 0
    _efi_path=${ disk_efiLoaderPath "${_R[BOOT_LOADER]:-systemd-boot}"; }
    disk_efiRegister "${_R[DISK_TARGET]}" "$_efi_path" NixOS
}
