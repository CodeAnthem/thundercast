#!/usr/bin/env bash
# ==================================================================================================
# disk utility - mount / unmount target root
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

# Description: Unmount leftover target root from a previous attempt.
# Arguments:
# - root: <String|optional> Mount root (default /mnt)
disk_unmountTarget() {
    local root="${1:-/mnt}"
    mountpoint -q "$root" 2>/dev/null || return 0
    warn "Unmounting leftover ${root} from a previous install attempt"
    umount -R "$root"
}

# Description: Mount nixos root + boot under mount root.
# Arguments:
# - use_encryption: <Bool>
# - root:           <String|optional> default /mnt
disk_mountRoot() {
    local use_encryption="${1:-false}"
    local root="${2:-/mnt}"

    log "Mounting filesystems"
    umount -R "$root" 2>/dev/null || true

    if [[ "$use_encryption" == "true" ]]; then
        log "Mounting encrypted root"
        mount /dev/mapper/cryptroot "$root" || return 1
    else
        log "Mounting standard root"
        mount /dev/disk/by-label/nixos "$root" || return 1
    fi

    log "Mounting boot partition"
    mkdir -p "${root}/boot" || return 1
    mount /dev/disk/by-label/boot "${root}/boot" || return 1
    mkdir -p "${root}/nix/store"

    log "Filesystems mounted successfully"
    return 0
}
