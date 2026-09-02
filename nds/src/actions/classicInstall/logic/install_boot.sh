#!/usr/bin/env bash
# ==================================================================================================
# DPS Project - Bootstrap NixOS - A NixOS Deployment System
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-30 | Modified: 2026-08-03
# Description:   Bootloader registration (EFI NVRAM entry)
# Feature:       No keyfile is placed on the target — LUKS key (if used) lives on a USB stick
# ==================================================================================================

# Description: Whether the live system (or configured mode) is UEFI.
# Uses BOOT_UEFI_MODE when set; otherwise detects from firmware.
# Returns:
# - <Bool> 0 when UEFI
_nds_install_live_is_uefi() {
    local configured
    nds_install_ctx_ensure
    configured="${ nds_install_ctx_get BOOT_UEFI_MODE; }"
    if [[ "$configured" == "true" ]]; then return 0; fi
    if [[ "$configured" == "false" ]]; then return 1; fi
    [[ -d /sys/firmware/efi/efivars ]]
}

# Description: EFI loader path for efibootmgr from the configured bootloader preset.
# Returns:
# - <String> Backslash-separated EFI path (stdout)
_nds_install_efi_loader_path() {
    local loader
    loader="${ nds_cfg_get BOOT_LOADER; }"
    loader="${loader:-systemd-boot}"
    case "$loader" in
        grub) printf '%s' '\\EFI\\nixos\\grubx64.efi' ;;
        refind) printf '%s' '\\EFI\\refind\\refind_x64.efi' ;;
        systemd-boot|*) printf '%s' '\\EFI\\systemd\\systemd-bootx64.efi' ;;
    esac
}

# Description: Whether partition 1 on disk is a GPT BIOS boot (bios_grub) partition.
# Arguments:
# - disk: <String> Block device
# Returns:
# - <Bool> 0 when bios_grub is present
_nds_install_disk_has_bios_grub() {
    local disk="$1"

    [[ -n "$disk" && -b "$disk" ]] || return 1
    parted "$disk" print 2>/dev/null | grep -qiE 'bios_grub|BIOS boot'
}

# Description: True when a bios_grub partition contains boot code (GRUB core.img).
# Arguments:
# - part: <String> Partition block device (e.g. /dev/sda1)
# Returns:
# - <Bool> 0 when non-empty / GRUB present
_nds_install_bios_grub_populated() {
    local part="$1"

    [[ -b "$part" ]] || return 1
    dd if="$part" bs=512 count=4 status=none 2>/dev/null | grep -aq GRUB
}

# Description: True when GRUB BIOS boot code is present (MBR or GPT bios_grub).
# Arguments:
# - disk: <String> Target block device
# Returns:
# - <Bool> 0 when boot code is present
_nds_install_grub_bios_boot_ok() {
    local disk="$1"

    [[ -n "$disk" && -b "$disk" ]] || return 1
    dd if="$disk" bs=512 count=1 status=none 2>/dev/null | grep -aq GRUB && return 0
    if _nds_install_disk_has_bios_grub "$disk" && _nds_install_bios_grub_populated "${disk}1"; then
        return 0
    fi
    return 1
}

# Description: Run grub-install on the target for BIOS/GPT when boot code is missing.
# Arguments:
# - disk: <String> Target block device
# Returns:
# - <Bool> 0 on success
_nds_install_grub_install_bios() {
    local disk="$1" root log

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    log="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"

    [[ -e "${root}/boot/grub/grub.cfg" ]] || return 1
    _nds_install_nix_system_profile_ok "$root" || return 1

    info "Installing GRUB boot code on ${disk} (BIOS)"
    # Prefer store profile path; fall back to current-system PATH inside the enter.
    if ! nixos-enter --root "$root" -- bash -c \
        "grub-install --target=i386-pc --recheck \"$disk\"" \
        >>"$log" 2>&1; then
        return 1
    fi
    nds_install_log "grub: installed BIOS boot code on ${disk}"
    _nds_install_grub_bios_boot_ok "$disk"
}

# Description: Register the NixOS EFI boot entry in firmware NVRAM.
# nixos-install runs bootctl in a chroot where efivars is not writable, so the
# bootloader files are copied but no NVRAM entry is created — some firmware
# (e.g. VMware) then shows "no OS found". This writes the entry from the host.
# Arguments:
# - disk: <String> Target block device (ESP is partition 1)
# Returns:
# - <Bool> 0 on success or when BIOS mode; 1 when UEFI registration fails
_nds_install_register_efi_entry() {
    local disk="$1"
    local loader_path

    _nds_install_live_is_uefi || return 0

    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        error "Configured UEFI install but live ISO is not booted in UEFI mode"
        error "Boot the NixOS ISO in UEFI mode, or pick a BIOS bootloader (GRUB)"
        return 1
    fi

    loader_path=${ _nds_install_efi_loader_path; }

    if ! command -v efibootmgr &>/dev/null; then
        error "efibootmgr not available — cannot register EFI boot entry"
        error "Loader: ${loader_path} on ${disk}1"
        return 1
    fi

    if efibootmgr --create --disk "$disk" --part 1 \
        --label "NixOS" \
        --loader "$loader_path" \
        >/dev/null 2>&1; then
        log "Registered EFI boot entry: NixOS -> ${loader_path}"
        nds_install_log "EFI boot entry registered for ${disk}1 (${loader_path})"
        return 0
    fi

    error "efibootmgr could not create the boot entry"
    error "Loader: ${loader_path} on ${disk}1"
    return 1
}
