#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install tools — disk detection (read-only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2026-07-06
# Description:   Disk state detection helpers (no prompts)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# DETECTION HELPERS (INTERNAL)
# ----------------------------------------------------------------------------------

# _nds_install_partition_disk_has_label
# - Returns 0 if disk has a partition table label (e.g., GPT/MBR), else 1
_nds_install_partition_disk_has_label() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    local out; out=$(lsblk -no PTTYPE "$disk" 2>/dev/null || true)
    [[ -n "$out" ]]
}

# _nds_install_partition_disk_has_partitions
# - Returns 0 if disk has child partitions, else 1
_nds_install_partition_disk_has_partitions() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -no NAME "$disk" 2>/dev/null | tail -n +2 | grep -q .
}

# _nds_install_partition_partitions_have_filesystems
# - Returns 0 if any partition has a recognizable filesystem (blkid or lsblk FSTYPE)
_nds_install_partition_partitions_have_filesystems() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # blkid detection first
    if blkid "$disk"* 2>/dev/null | grep -qE 'TYPE="[^"]+"'; then
        return 0
    fi
    # fallback to lsblk FSTYPE
    lsblk -no FSTYPE "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

# _nds_install_partition_in_use
# - Returns 0 if any partition is mounted/in use, else 1
_nds_install_partition_in_use() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -no MOUNTPOINT "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

# _nds_install_partition_has_known_signatures
# - Returns 0 if LVM PV, mdraid, or other metadata signatures are detected, else 1
_nds_install_partition_has_known_signatures() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    # LVM PV signature
    if command -v pvs >/dev/null 2>&1 && pvs --noheadings "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    # mdadm RAID signature
    if command -v mdadm >/dev/null 2>&1 && mdadm --examine --brief "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# _nds_install_partition_summarize_disk
# - Prints a short summary table of disk/partitions
_nds_install_partition_summarize_disk() {
    local disk="$1"; [[ -n "$disk" ]] || return 1
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" 2>/dev/null
}

# _nds_install_partition_check_disk_state
# - Echoes one of: wiped | empty_parts | has_fs | in_use
_nds_install_partition_check_disk_state() {
    local disk="$1"; [[ -n "$disk" ]] || { echo "wiped"; return 1; }

    if _nds_install_partition_in_use "$disk"; then
        echo "in_use"; return 0
    fi
    if _nds_install_partition_partitions_have_filesystems "$disk" || _nds_install_partition_has_known_signatures "$disk"; then
        echo "has_fs"; return 0
    fi
    if _nds_install_partition_disk_has_label "$disk" || _nds_install_partition_disk_has_partitions "$disk"; then
        echo "empty_parts"; return 0
    fi
    echo "wiped"; return 0
}
