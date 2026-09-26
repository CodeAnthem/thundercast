#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook diagnostics
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Compact snapshots in the session diag log.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -g _NDS_REALIZE_DIAG_LAST=""

_nds_cook_diag_log() {
    if declare -f nds_session_dir >/dev/null; then
        printf '%s\n' "${ nds_session_dir logs; }/diag.log"
    else
        printf '%s\n' /tmp/nds-diag.log
    fi
}

_nds_cook_diag_write() {
    local _diag_path
    _diag_path=${ _nds_cook_diag_log; }
    mkdir -p "$(dirname "$_diag_path")"
    printf '%s\n' "$1" >>"$_diag_path"
}

nds_cook_diag_disk() {
    local _diag_disk=${1:-} _diag_path
    _nds_cook_diag_write ""
    _nds_cook_diag_write "=== disk: ${_diag_disk:-unknown} ==="
    [[ -n "$_diag_disk" ]] || return 0
    _diag_path=${ _nds_cook_diag_log; }
    lsblk -f "$_diag_disk" >>"$_diag_path" 2>&1 || true
    command -v parted >/dev/null && parted "$_diag_disk" print >>"$_diag_path" 2>&1 || true
    blkid "${_diag_disk}"* >>"$_diag_path" 2>&1 || true
}

nds_cook_diag_snapshot() {
    local _diag_reason=${1:-snapshot} _diag_path _diag_disk="" _diag_loader="" _diag_uefi=""
    [[ "$_NDS_REALIZE_DIAG_LAST" == "$_diag_reason" ]] && return 0
    _NDS_REALIZE_DIAG_LAST=$_diag_reason
    if [[ -n ${_NDS_REALIZE_AA:-} ]]; then
        local -n _diag_R=${_NDS_REALIZE_AA}
        _diag_disk=${_diag_R[DISK_TARGET]:-}
        _diag_loader=${_diag_R[BOOT_LOADER]:-}
        _diag_uefi=${_diag_R[BOOT_UEFI_MODE]:-}
    fi
    _nds_cook_diag_write ""
    _nds_cook_diag_write "=== ${_diag_reason} ==="
    _nds_cook_diag_write "BOOT_UEFI_MODE=${_diag_uefi:-unset}"
    _nds_cook_diag_write "BOOT_LOADER=${_diag_loader:-unset}"
    _nds_cook_diag_write "DISK_TARGET=${_diag_disk:-unset}"
    _diag_path=${ _nds_cook_diag_log; }
    if command mountpoint -q "$_NDS_TARGET_ROOT" 2>/dev/null; then
        _nds_cook_diag_write "mnt_mounted=yes"
    else
        _nds_cook_diag_write "mnt_mounted=no"
    fi
    command -v findmnt >/dev/null && findmnt -R "$_NDS_TARGET_ROOT" >>"$_diag_path" 2>&1 || true
}

nds_cook_diag_after_partition() {
    nds_cook_diag_disk "${1:-}"
    nds_cook_diag_snapshot "after partition"
}

nds_cook_diag_step_failure() {
    local _diag_label=$1 _diag_verbose _diag_line
    nds_cook_diag_snapshot "FAILED: ${_diag_label}"
    _diag_verbose=${NDS_NIXOS_INSTALL_LOG:-}
    [[ -f "$_diag_verbose" ]] || return 0
    _nds_cook_diag_write "=== log tail ==="
    while IFS= read -r _diag_line; do
        _nds_cook_diag_write "$_diag_line"
    done < <(tail -n 40 "$_diag_verbose" 2>/dev/null || true)
}

nds_cook_diag() {
    nds_cook_diag_snapshot "${1:-snapshot}"
}
