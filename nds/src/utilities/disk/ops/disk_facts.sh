#!/usr/bin/env bash
# ==================================================================================================
# disk - block device facts (blkid / findmnt / LUKS UUID) — read only
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-03 | Modified: 2026-09-03
# ==================================================================================================

# Description: blkid UUID for a device node (empty when unknown).
# Arguments:
# - device: <String> Block device path
# Returns:
# - <String> UUID (stdout)
disk_blkidUuid() {
    blkid -s UUID -o value "$1" 2>/dev/null || true
}

# Description: blkid filesystem TYPE for a device node.
# Arguments:
# - device:  <String> Block device path
# - default: <String|optional> Fallback when unknown
# Returns:
# - <String> fs type (stdout)
disk_blkidType() {
    local t
    t=$(blkid -s TYPE -o value "$1" 2>/dev/null || true)
    printf '%s\n' "${t:-${2:-}}"
}

# Description: Source device mounted at a path.
# Arguments:
# - mountpoint: <String> Mount path (e.g. /mnt)
# Returns:
# - <String> device (stdout), empty when not mounted
disk_findmntSource() {
    findmnt -n -o SOURCE --target "$1" 2>/dev/null || true
}

# Description: UUID of the LUKS container backing cryptroot (nds, disko, nvme layouts).
# Arguments:
# - disk: <String|optional> Target disk to scan when cryptroot is not open
# Returns:
# - <String> UUID (stdout); 1 when not found
disk_findLuksUuid() {
    local disk="${1:-}"
    local part uuid backing

    if [[ -e /dev/mapper/cryptroot ]]; then
        backing=$(cryptsetup status cryptroot 2>/dev/null | awk '/device:/ {print $2}')
        if [[ -n "$backing" ]]; then
            uuid=$(disk_blkidUuid "$backing")
            [[ -n "$uuid" ]] && { printf '%s\n' "$uuid"; return 0; }
        fi
    fi

    [[ -n "$disk" ]] || return 1
    for part in "${disk}"*; do
        [[ -b "$part" ]] || continue
        [[ "$(disk_blkidType "$part")" == "crypto_LUKS" ]] || continue
        uuid=$(disk_blkidUuid "$part")
        [[ -n "$uuid" ]] && { printf '%s\n' "$uuid"; return 0; }
    done
    uuid=$(disk_blkidUuid "${ disk_part "$disk" 2; }")
    [[ -n "$uuid" ]] && { printf '%s\n' "$uuid"; return 0; }
    return 1
}
