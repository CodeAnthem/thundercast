#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disko partitioning (shot caller wrappers → utilities/disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-03 | Modified: 2026-09-02
# ==================================================================================================

_nds_install_partition_disko_generate_params() {
    nds_requireUtility disk || return 1
    _disk_diskoGenerateParams "$@"
}

_nds_install_partition_disko_pick_template() {
    nds_requireUtility disk || return 1
    _disk_diskoTemplate
}

_nds_install_partition_disko_run() {
    nds_requireUtility disk || return 1
    disk_diskoRun "$@"
}

# Description: Apply Disko then optional install diagnostics.
_nds_install_partition_disko_apply() {
    local disk="$1" fs_type="$2" swap_mib="$3" separate_home="$4" home_size="$5" enc="$6" unlock="$7" user_file="$8"
    local work_dir rc=0

    nds_requireUtility disk || return 1
    work_dir="${NDS_RUNTIME_DIR:-/tmp}/disko"
    disk_diskoApply \
        "$disk" "$fs_type" "$swap_mib" "$separate_home" "$home_size" "$enc" "$unlock" \
        "$user_file" "${NDS_CTX_BOOT_LOADER:-systemd-boot}" "$work_dir" || rc=$?

    if declare -f nds_install_diag_after_partition &>/dev/null; then
        nds_install_diag_after_partition "$disk"
    fi
    return "$rc"
}
