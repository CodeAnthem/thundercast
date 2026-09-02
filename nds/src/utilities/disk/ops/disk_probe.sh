#!/usr/bin/env bash
# ==================================================================================================
# disk utility - read-only disk state probe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

_disk_hasLabel() {
    local disk="$1" out
    [[ -n "$disk" ]] || return 1
    out=$(lsblk -no PTTYPE "$disk" 2>/dev/null || true)
    [[ -n "$out" ]]
}

_disk_hasPartitions() {
    local disk="$1"
    [[ -n "$disk" ]] || return 1
    lsblk -no NAME "$disk" 2>/dev/null | tail -n +2 | grep -q .
}

_disk_partitionsHaveFs() {
    local disk="$1"
    [[ -n "$disk" ]] || return 1
    if blkid "$disk"* 2>/dev/null | grep -qE 'TYPE="[^"]+"'; then
        return 0
    fi
    lsblk -no FSTYPE "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

_disk_inUse() {
    local disk="$1"
    [[ -n "$disk" ]] || return 1
    lsblk -no MOUNTPOINT "$disk" 2>/dev/null | tail -n +2 | grep -qE "[^[:space:]]"
}

_disk_hasKnownSignatures() {
    local disk="$1"
    [[ -n "$disk" ]] || return 1
    if command -v pvs >/dev/null 2>&1 && pvs --noheadings "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    if command -v mdadm >/dev/null 2>&1 && mdadm --examine --brief "$disk"* 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# Description: Summarize disk layout (stdout).
disk_summarize() {
    local disk="$1"
    [[ -n "$disk" ]] || return 1
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$disk" 2>/dev/null
}

# Description: Probe disk state for format readiness.
# Arguments:
# - disk: <String> Block device
# Returns:
# - <String> wiped|empty_parts|has_fs|in_use on stdout
disk_probeState() {
    local disk="$1"
    [[ -n "$disk" ]] || { printf 'wiped\n'; return 1; }
    if _disk_inUse "$disk"; then
        printf 'in_use\n'; return 0
    fi
    if _disk_partitionsHaveFs "$disk" || _disk_hasKnownSignatures "$disk"; then
        printf 'has_fs\n'; return 0
    fi
    if _disk_hasLabel "$disk" || _disk_hasPartitions "$disk"; then
        printf 'empty_parts\n'; return 0
    fi
    printf 'wiped\n'
    return 0
}

# Description: True when disk exists as a block device.
disk_canUse() {
    local disk="$1"
    [[ -n "$disk" && -b "$disk" ]]
}
