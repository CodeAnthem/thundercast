#!/usr/bin/env bash
# ==================================================================================================
# NDS - Boot preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-15
# ==================================================================================================

boot_defaults() {
    local uefi_default bootloader_default
    if [[ -d /sys/firmware/efi/efivars ]]; then
        uefi_default=true
        bootloader_default=systemd-boot
    else
        uefi_default=false
        bootloader_default=grub
    fi
    nds_cfg_set BOOT_UEFI_MODE "$uefi_default"
    nds_cfg_set BOOT_LOADER "$bootloader_default"
}

boot_configure() {
    nds_cfg_section_title "Boot"
    nds_cfg_ask_toggle BOOT_UEFI_MODE "UEFI mode" "$(nds_cfg_get BOOT_UEFI_MODE)"
    nds_cfg_ask_choice BOOT_LOADER "Bootloader" "systemd-boot|grub|refind" \
        "systemd-boot=systemd-boot (UEFI)|grub=GRUB (BIOS + UEFI)|refind=rEFInd (UEFI)" \
        "$(nds_cfg_get BOOT_LOADER)"
}

boot_summary() {
    nds_cfg_summary_row "UEFI mode" "$(nds_cfg_display_toggle "$(nds_cfg_get BOOT_UEFI_MODE)")"
    nds_cfg_summary_row "Bootloader" "$(nds_cfg_get BOOT_LOADER)"
}

boot_validate() {
    local uefi bootloader
    uefi=$(nds_cfg_get BOOT_UEFI_MODE)
    bootloader=$(nds_cfg_get BOOT_LOADER)
    if [[ "$uefi" != true && "$bootloader" == systemd-boot ]]; then
        validation_error "systemd-boot requires UEFI — pick GRUB or enable UEFI mode"
        return 1
    fi
    if [[ "$uefi" != true && "$bootloader" == refind ]]; then
        validation_error "rEFInd requires UEFI — pick GRUB or enable UEFI mode"
        return 1
    fi
    if [[ "$uefi" == true && ! -d /sys/firmware/efi/efivars ]]; then
        validation_error "UEFI mode is on but the live ISO is BIOS-booted"
        return 1
    fi
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=boot_defaults \
        configure=boot_configure \
        validate=boot_validate \
        summary=boot_summary
fi

NDS_PRESET_PRIORITY=30
NDS_PRESET_DISPLAY="Boot"
