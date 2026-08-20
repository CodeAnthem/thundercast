#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk preparation (partition, mount, hardware gen)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-10-28 | Modified: 2026-08-16
# ==================================================================================================

# Description: Partition adapter — encrypt path uses _nds_install_format_luks from encryption.sh.
# Arguments:
# - disk:           <String> Target block device
# - use_encryption: <Bool> Encrypt root partition
# - uefi_mode:      <Bool|optional> UEFI layout; auto-detect when empty
_nds_install_partition_disk() {
    local disk="$1"
    local use_encryption="${2:-false}"
    local uefi_mode="${3:-}"

    if [[ "$use_encryption" == "true" ]]; then
        nds_install_partition_disk "$disk" "$use_encryption" "$uefi_mode" "_nds_install_format_luks"
    else
        nds_install_partition_disk "$disk" "$use_encryption" "$uefi_mode"
    fi
}

# Description: Mount root + boot for NixOS installation.
# Arguments:
# - use_encryption: <Bool> Mount cryptroot when true
_nds_install_mount_filesystems() {
    local use_encryption="${1:-false}"

    log "Mounting filesystems"
    umount -R /mnt 2>/dev/null || true

    if [[ "$use_encryption" == "true" ]]; then
        log "Mounting encrypted root"
        mount /dev/mapper/cryptroot /mnt || return 1
    else
        log "Mounting standard root"
        mount /dev/disk/by-label/nixos /mnt || return 1
    fi

    log "Mounting boot partition"
    mkdir -p /mnt/boot || return 1
    mount /dev/disk/by-label/boot /mnt/boot || return 1
    mkdir -p /mnt/nix/store

    log "Filesystems mounted successfully"
    if declare -f nds_install_diag_after_mount &>/dev/null; then
        nds_install_diag_after_mount
    fi
    return 0
}

# Description: Partition and mount target disk from gathered NDS_CTX_* context.
# Arguments:
# - skip_hardware: <Bool> When true, skip hardware/facter generation
nds_install_auto() {
    local skip_hardware="${1:-false}"

    _nds_install_gather_context

    log "Starting NixOS installation"
    log "Disk: ${NDS_CTX_DISK} | strategy: ${NDS_CTX_DISK_STRATEGY} | encryption: ${NDS_CTX_ENCRYPTION} | host: ${NDS_CTX_HOSTNAME}"

    if [[ "$NDS_CTX_DISK_STRATEGY" == "flake" ]]; then
        warn "disk strategy 'flake' skips NDS partitioning — use only from flake install with /mnt ready"
        return 0
    fi

    _nds_install_unmount_leftover_target || return 1
    _nds_install_nix_ensure_live_store_space 64 || return 1

    if [[ "$NDS_CTX_DISK_STRATEGY" == "disko" ]]; then
        nds_step_exec "Running disko" nds_partition_run_disko_from_config || return 1
    else
        if [[ "$NDS_CTX_ENCRYPTION" == "true" ]]; then
            nds_step_exec "Generating encryption secrets" _nds_install_generate_encryption_secrets || return 1
        fi
        nds_step_exec "Partitioning disk" _nds_install_partition_disk \
            "$NDS_CTX_DISK" "$NDS_CTX_ENCRYPTION" "$NDS_CTX_BOOT_UEFI_MODE" || return 1
        nds_step_exec "Mounting filesystems" _nds_install_mount_filesystems "$NDS_CTX_ENCRYPTION" || return 1
    fi

    if [[ "$NDS_CTX_ENCRYPTION" == "true" && "$NDS_CTX_REMOTE_UNLOCK" == "true" ]]; then
        nds_step_exec "Setting up initrd SSH keys" _nds_install_setup_initrd_ssh_keys || return 1
    fi

    if [[ "$skip_hardware" != "true" ]]; then
        nds_step_exec "Generating hardware configuration" _nds_install_generate_hardware_config || return 1
    fi
    log "NixOS disk preparation completed successfully"
    return 0
}
