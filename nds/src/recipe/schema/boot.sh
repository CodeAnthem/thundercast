#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group boot
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_detect_bootUefi() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        printf '%s\n' true
    else
        printf '%s\n' false
    fi
}

nds_detect_bootLoader() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        printf '%s\n' systemd-boot
    else
        printf '%s\n' grub
    fi
}

nds_check_boot() {
    local -n _nds_boot_aa=$1
    local _nds_boot_n=0
    local _nds_boot_uefi=${_nds_boot_aa[BOOT_UEFI_MODE]:-}
    local _nds_boot_loader=${_nds_boot_aa[BOOT_LOADER]:-}
    if [[ "$_nds_boot_uefi" != true && "$_nds_boot_loader" == systemd-boot ]]; then
        error "BOOT_LOADER: systemd-boot requires UEFI"
        _nds_boot_n=$((_nds_boot_n + 1))
    fi
    if [[ "$_nds_boot_uefi" != true && "$_nds_boot_loader" == refind ]]; then
        error "BOOT_LOADER: rEFInd requires UEFI"
        _nds_boot_n=$((_nds_boot_n + 1))
    fi
    if [[ "$_nds_boot_uefi" == true && ! -d /sys/firmware/efi/efivars ]]; then
        error "BOOT_UEFI_MODE: UEFI mode is on but the machine is BIOS-booted"
        _nds_boot_n=$((_nds_boot_n + 1))
    fi
    return "$_nds_boot_n"
}

nds_schema_group boot "Boot" --check nds_check_boot
nds_schema_field boot BOOT_UEFI_MODE bool --detect nds_detect_bootUefi --label 'UEFI mode'
nds_schema_field boot BOOT_LOADER choice --detect nds_detect_bootLoader \
    --choices 'systemd-boot|grub|refind' \
    --labels 'systemd-boot=systemd-boot|grub=GRUB|refind=rEFInd' --label 'Bootloader'
