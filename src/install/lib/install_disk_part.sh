#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk partition path helper (standalone)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-28 | Modified: 2026-07-28
# Description:   Resolve block device paths for partition indices
# ==================================================================================================

# Description: Return partition device path for a disk index (handles nvme/mmcblk).
# Arguments:
# - disk:  <String> Block device (e.g. /dev/nvme0n1)
# - index: <String> Partition index
# Returns:
# - <String> partition path on stdout
nds_install_disk_part() {
    local disk="$1"
    local index="$2"
    if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
        printf '%s\n' "${disk}p${index}"
    else
        printf '%s\n' "${disk}${index}"
    fi
}
