#!/usr/bin/env bash
# ==================================================================================================
# NDS - Disk state detection (wrappers → utilities/disk)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2025-11-04 | Modified: 2026-09-02
# Description:   Thin aliases for install callers; logic lives in disk_probe
# ==================================================================================================

_nds_install_require_disk() {
    nds_requireUtility disk
}

_nds_install_partition_disk_has_label() {
    _nds_install_require_disk || return 1
    _disk_hasLabel "$@"
}

_nds_install_partition_disk_has_partitions() {
    _nds_install_require_disk || return 1
    _disk_hasPartitions "$@"
}

_nds_install_partition_partitions_have_filesystems() {
    _nds_install_require_disk || return 1
    _disk_partitionsHaveFs "$@"
}

_nds_install_partition_in_use() {
    _nds_install_require_disk || return 1
    _disk_inUse "$@"
}

_nds_install_partition_has_known_signatures() {
    _nds_install_require_disk || return 1
    _disk_hasKnownSignatures "$@"
}

_nds_install_partition_summarize_disk() {
    _nds_install_require_disk || return 1
    disk_summarize "$@"
}

_nds_install_partition_check_disk_state() {
    _nds_install_require_disk || return 1
    disk_probeState "$@"
}
