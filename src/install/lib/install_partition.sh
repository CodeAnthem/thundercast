#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk partitioning (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   GPT partitioning for NixOS install (argument-only)
# ==================================================================================================

# Description: Partition disk for NixOS installation.
# Arguments:
# - disk:            <String> Target block device
# - use_encryption:  <Bool> When true, call format_luks_fn on root partition
# - uefi_mode:       <Bool|empty> UEFI layout when true; auto-detect from firmware when empty
# - format_luks_fn:  <String|optional> Function name: format_luks_fn root_partition
# Returns:
# - <Bool> 0 on success
nds_install_partition_disk() {
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

    if [[ ! -b "$disk" ]]; then
        if declare -f error &>/dev/null; then
            error "Target disk does not exist: $disk"
        fi
        return 1
    fi

    if declare -f log &>/dev/null; then
        log "Partitioning disk: $disk (firmware: $([[ "$uefi_mode" == "true" ]] && echo UEFI || echo BIOS))"
        log "Cleaning up existing partitions"
    fi
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true

    for part in "${disk}"*; do
        [[ -b "$part" ]] && wipefs -a "$part" 2>/dev/null || true
    done

    parted "$disk" --script -- mklabel gpt || return 1

    if [[ "$uefi_mode" == "true" ]]; then
        parted "$disk" --script -- mkpart ESP fat32 1MiB 512MiB || return 1
        parted "$disk" --script -- set 1 esp on || return 1
        parted "$disk" --script -- mkpart primary 512MiB 100% || return 1
        boot_idx=1
        root_idx=2
    else
        parted "$disk" --script -- mkpart bios_grub 1MiB 3MiB || return 1
        parted "$disk" --script -- set 1 bios_grub on || return 1
        parted "$disk" --script -- mkpart boot fat32 3MiB 515MiB || return 1
        parted "$disk" --script -- mkpart primary 515MiB 100% || return 1
        boot_idx=2
        root_idx=3
    fi

    sleep 2
    partprobe "$disk" || true

    boot_part=$(nds_install_disk_part "$disk" "$boot_idx")
    root_part=$(nds_install_disk_part "$disk" "$root_idx")

    if declare -f log &>/dev/null; then
        log "Formatting boot partition"
    fi
    mkfs.fat -F 32 -n boot "$boot_part" || return 1

    if [[ "$use_encryption" == "true" ]]; then
        if declare -f log &>/dev/null; then
            log "Setting up encrypted root partition"
        fi
        [[ -n "$format_luks_fn" ]] && declare -f "$format_luks_fn" &>/dev/null || {
            if declare -f error &>/dev/null; then
                error "Encrypted install requires format_luks_fn callback"
            fi
            return 1
        }
        "$format_luks_fn" "$root_part" || return 1
    else
        if declare -f log &>/dev/null; then
            log "Setting up standard root partition"
        fi
        mkfs.ext4 -L nixos "$root_part" || return 1
    fi

    if declare -f nds_install_diag_after_partition &>/dev/null; then
        nds_install_diag_after_partition "$disk"
    fi

    return 0
}
