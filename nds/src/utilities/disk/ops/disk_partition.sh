#!/usr/bin/env bash
# ==================================================================================================
# disk utility - NDS GPT partition layout
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-09-27
# ==================================================================================================

# Wait until udev has published the filesystems just written. lsblk and by-label are stale until then.
_disk_publish() {
    command -v udevadm >/dev/null 2>&1 || return 0
    sync || true
    udevadm settle --timeout=15 || true
}

# Loop devices ignore a plain partprobe often enough that the partition nodes never appear.
_disk_reread() {
    local disk=$1
    partprobe "$disk" || true
    [[ "$disk" == /dev/loop* ]] || return 0
    losetup -c "$disk" 2>/dev/null || true
    partx -u "$disk" 2>/dev/null || partx -a "$disk" 2>/dev/null || true
}

# Non-loop paths return immediately so a stubbed unit run does not wait on /dev/sda.
_disk_part_ready() {
    local part=$1 i
    [[ "$part" == /dev/loop* ]] || return 0
    for ((i = 0; i < 50; i++)); do
        [[ -b "$part" ]] && return 0
        sleep 0.1
    done
    err "Partition device did not appear: ${part}"
    return 1
}

# Description: Partition disk for NixOS (NDS layout). Optional LUKS via callback name.
# Arguments:
# - disk:           <String> Target block device
# - use_encryption: <Bool>
# - uefi_mode:      <Bool|empty> auto-detect when empty
# - format_luks_fn: <String|optional> Function name: fn root_partition
disk_partition() {
    local disk="$1"
    local use_encryption="${2:-false}"
    local uefi_mode="${3:-}"
    local format_luks_fn="${4:-}"
    local boot_idx root_idx boot_part root_part

    if [[ -z "$uefi_mode" ]]; then
        if [[ -d /sys/firmware/efi ]]; then
            uefi_mode=true
        else
            uefi_mode=false
        fi
    fi

    if ! disk_canUse "$disk"; then
        err "Target disk does not exist: $disk"
        return 1
    fi

    verbose "Partitioning disk: $disk (firmware: $([[ "$uefi_mode" == "true" ]] && echo UEFI || echo BIOS))"
    verbose "Cleaning up existing partitions"
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true

    for part in "${disk}"*; do
        [[ -b "$part" ]] && wipefs -a "$part" 2>/dev/null || true
    done

    _disk_cmd parted "$disk" --script -- mklabel gpt || return 1

    if [[ "$uefi_mode" == "true" ]]; then
        _disk_cmd parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB || return 1
        _disk_cmd parted "$disk" --script -- set 1 esp on || return 1
        _disk_cmd parted "$disk" --script -- mkpart primary 512MiB 100% || return 1
        boot_idx=1
        root_idx=2
    else
        _disk_cmd parted "$disk" --script -- mkpart bios_grub 1MiB 3MiB || return 1
        _disk_cmd parted "$disk" --script -- set 1 bios_grub on || return 1
        _disk_cmd parted "$disk" --script -- mkpart boot fat32 3MiB 515MiB || return 1
        _disk_cmd parted "$disk" --script -- mkpart primary 515MiB 100% || return 1
        boot_idx=2
        root_idx=3
    fi

    sleep 2
    _disk_reread "$disk"

    boot_part=${ disk_part "$disk" "$boot_idx"; }
    root_part=${ disk_part "$disk" "$root_idx"; }
    _disk_part_ready "$boot_part" || return 1
    _disk_part_ready "$root_part" || return 1
    # udev probes the new partitions and holds them open. Settle before mkfs.
    _disk_publish

    verbose "Formatting boot partition"
    _disk_cmd mkfs.fat -F 32 -n boot "$boot_part" || return 1

    if [[ "$use_encryption" == "true" ]]; then
        verbose "Setting up encrypted root partition"
        [[ -n "$format_luks_fn" ]] && declare -f "$format_luks_fn" &>/dev/null || {
            err "Encrypted install requires format_luks_fn callback"
            return 1
        }
        "$format_luks_fn" "$root_part" || return 1
    else
        verbose "Setting up standard root partition"
        _disk_cmd mkfs.ext4 -F -L nixos "$root_part" || return 1
    fi
    _disk_publish
    if declare -f nds_diagnose_append >/dev/null; then
        nds_diagnose_append ""
        nds_diagnose_append "=== disk ${disk} after partition ==="
        nds_diagnose_append "$(lsblk -f "$disk" 2>&1 || true)"
        nds_diagnose_append "$(parted "$disk" print 2>&1 || true)"
        nds_diagnose_append "$(blkid "${disk}"* 2>&1 || true)"
    fi
    return 0
}
