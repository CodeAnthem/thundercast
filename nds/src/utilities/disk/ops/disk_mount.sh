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
    _disk_cmd umount -R "$root"
}

# Description: Mount nixos root + boot under mount root.
# Arguments:
# - use_encryption: <Bool>
# - root:           <String|optional> default /mnt
disk_mountRoot() {
    local use_encryption="${1:-false}"
    local root="${2:-/mnt}"

    verbose "Mounting filesystems"
    _disk_quiet umount -R "$root"

    if [[ "$use_encryption" == "true" ]]; then
        verbose "Mounting encrypted root"
        mount /dev/mapper/cryptroot "$root" || return 1
    else
        verbose "Mounting standard root"
        mount /dev/disk/by-label/nixos "$root" || return 1
    fi

    verbose "Mounting boot partition"
    mkdir -p "${root}/boot" || return 1
    mount /dev/disk/by-label/boot "${root}/boot" || return 1
    mkdir -p "${root}/nix/store"

    verbose "Filesystems mounted successfully"
    if declare -f nds_diagnose_append >/dev/null; then
        nds_diagnose_append ""
        nds_diagnose_append "=== mounts under ${root} ==="
        nds_diagnose_append "$(findmnt -R "$root" 2>&1 || true)"
    fi
    return 0
}
