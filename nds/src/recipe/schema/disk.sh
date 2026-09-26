#!/usr/bin/env bash
# ==================================================================================================
# NDS - Schema group disk
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_detect_firstDisk() {
    local _nds_disk_found
    _nds_disk_found=$(find /dev \( -name 'sd[a-z]' -o -name 'nvme[0-9]*n[0-9]*' -o -name 'vd[a-z]' \) 2>/dev/null | sort | head -n 1)
    printf '%s\n' "$_nds_disk_found"
}

nds_check_disk() {
    local -n _nds_disk_aa=$1
    if [[ ${_nds_disk_aa[DISK_STRATEGY]:-nds} != flake && -z ${_nds_disk_aa[DISK_TARGET]:-} ]]; then
        error "DISK_TARGET: required"
        return 1
    fi
    return 0
}

nds_schema_group disk "Disk" --check nds_check_disk
nds_schema_field disk DISK_TARGET disk --ask nds_ask_disk --detect nds_detect_firstDisk --label 'Target disk'
nds_schema_field disk DISK_STRATEGY choice --default nds \
    --choices 'nds|disko|flake' \
    --labels 'nds=NDS built-in|disko=Disko template|flake=Flake owns disk' --label 'Partitioning method'
nds_schema_field disk DISK_FS_TYPE choice --default ext4 --when 'DISK_STRATEGY=disko' \
    --choices 'ext4|btrfs' --label 'Root filesystem'
nds_schema_field disk DISK_SWAP_SIZE_MIB int --default 0 --min 0 --max 65536 --when 'DISK_STRATEGY=disko' \
    --label 'Swap size'
nds_schema_field disk DISK_DISKO_CONFIG file --when 'DISK_STRATEGY=disko' --label 'Disko config file'
