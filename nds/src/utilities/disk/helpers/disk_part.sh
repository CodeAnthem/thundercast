#!/usr/bin/env bash
# ==================================================================================================
# disk utility - partition path helper
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-09-02
# ==================================================================================================

# Description: Partition device path for a disk index (nvme/mmcblk aware).
# Arguments:
# - disk:  <String> Block device
# - index: <String> Partition index
# Returns:
# - <String> path on stdout
disk_part() {
    local disk="$1" index="$2"
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
        printf '%s\n' "${disk}p${index}"
    else
        printf '%s\n' "${disk}${index}"
    fi
}
