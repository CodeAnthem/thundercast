#!/usr/bin/env bash
# ==================================================================================================
# disk - bootloader / EFI / bios_grub probes (no prompts)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

# Description: EFI loader path for efibootmgr from a bootloader id.
# Arguments:
# - loader: <String> grub | refind | systemd-boot (default systemd-boot)
# Returns:
# - <String> Backslash-separated EFI path (stdout)
disk_efiLoaderPath() {
    local loader="${1:-systemd-boot}"
    case "$loader" in
        grub) printf '%s' '\\EFI\\nixos\\grubx64.efi' ;;
        refind) printf '%s' '\\EFI\\refind\\refind_x64.efi' ;;
        systemd-boot|*) printf '%s' '\\EFI\\systemd\\systemd-bootx64.efi' ;;
    esac
}

# Description: Whether partition table on disk has a GPT BIOS boot (bios_grub) partition.
# Arguments:
# - disk: <String> Block device
# Returns:
# - <Bool> 0 when bios_grub is present
disk_hasBiosGrub() {
    local disk="$1"
    [[ -n "$disk" && -b "$disk" ]] || return 1
    parted "$disk" print 2>/dev/null | grep -qiE 'bios_grub|BIOS boot'
}

# Description: True when a bios_grub partition contains boot code (GRUB core.img).
# Arguments:
# - part: <String> Partition block device
# Returns:
# - <Bool> 0 when non-empty / GRUB present
disk_biosGrubPopulated() {
    local part="$1"
    [[ -b "$part" ]] || return 1
    dd if="$part" bs=512 count=4 status=none 2>/dev/null | grep -aq GRUB
}

# Description: True when GRUB BIOS boot code is present (MBR signature or GPT bios_grub).
# Arguments:
# - disk: <String> Target block device
# Returns:
# - <Bool> 0 when boot code is present
disk_grubBiosBootOk() {
    local disk="$1"

    [[ -n "$disk" && -b "$disk" ]] || return 1
    dd if="$disk" bs=512 count=1 status=none 2>/dev/null | grep -aq GRUB && return 0
    disk_hasBiosGrub "$disk" && disk_biosGrubPopulated "${ disk_part "$disk" 1; }"
}

# Description: Run grub-install (i386-pc) inside the target via nixos-enter.
# Arguments:
# - disk: <String> Target block device
# - root: <String|optional> Target root mount (default /mnt)
# - log:  <String|optional> Append stdout/stderr here
# Returns:
# - <Bool> 0 when boot code is present afterwards
disk_grubInstallBios() {
    local disk="$1"
    local root="${2:-/mnt}"
    local log="${3:-${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}}"

    [[ -n "$disk" && -b "$disk" ]] || return 1
    [[ -e "${root}/boot/grub/grub.cfg" ]] || return 1
    nixos-enter --root "$root" -- bash -c \
        "grub-install --target=i386-pc --recheck \"$disk\"" >>"$log" 2>&1 || return 1
    disk_grubBiosBootOk "$disk"
}

# Description: True when the EFI binary for a bootloader exists on the mounted ESP.
# Arguments:
# - loader:   <String> grub | systemd-boot | refind
# - boot_dir: <String|optional> Mounted ESP (default /mnt/boot)
disk_efiFilesPresent() {
    local loader="${1:-systemd-boot}"
    local boot_dir="${2:-/mnt/boot}"
    local f

    case "$loader" in
        grub)
            for f in "${boot_dir}"/EFI/*/grub*.efi \
                "${boot_dir}/EFI/nixos/grubx64.efi" \
                "${boot_dir}/EFI/BOOT/BOOTX64.EFI"; do
                [[ -f "$f" ]] && return 0
            done
            return 1
            ;;
        refind) [[ -f "${boot_dir}/EFI/refind/refind_x64.efi" ]] ;;
        systemd-boot|*) [[ -f "${boot_dir}/EFI/systemd/systemd-bootx64.efi" ]] ;;
    esac
}

# Description: Create a firmware NVRAM boot entry with efibootmgr (ESP = partition 1).
# Arguments:
# - disk:        <String> Target block device
# - loader_path: <String> Backslash EFI path (see disk_efiLoaderPath)
# - label:       <String|optional> Entry label (default NixOS)
# Returns:
# - <Bool> 0 on success
disk_efiRegister() {
    local disk="$1"
    local loader_path="$2"
    local label="${3:-NixOS}"

    [[ -n "$disk" && -n "$loader_path" ]] || return 1
    [[ -d /sys/firmware/efi/efivars ]] || { err "live system is not UEFI-booted (no efivars)"; return 1; }
    command -v efibootmgr &>/dev/null || { err "efibootmgr not available"; return 1; }
    efibootmgr --create --disk "$disk" --part 1 --label "$label" --loader "$loader_path" >/dev/null 2>&1 \
        || { err "efibootmgr could not create ${label} -> ${loader_path} on ${disk}1"; return 1; }
    return 0
}
