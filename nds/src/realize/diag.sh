#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - install diagnostics (compact log, separate from nixos-install output)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-03
# Description:   Structured install state in NDS_INSTALL_DIAG_LOG (folded into nds.log)
# ==================================================================================================

declare -g _NDS_REALIZE_DIAG_LAST_KEY=""

_nds_realize_diag_log() {
    printf '%s\n' "${NDS_INSTALL_DIAG_LOG:-/tmp/nds_install_diag.log}"
}

_nds_realize_diag_write() {
    printf '%s\n' "$1" >>"${ _nds_realize_diag_log; }"
}

_nds_realize_diag_kv() {
    _nds_realize_diag_write "${1}=${2}"
}

# Description: Disk layout summary (lsblk / parted / blkid).
# Arguments:
# - disk: <String> Block device
nds_realize_diag_disk() {
    local disk="${1:-}"

    _nds_realize_diag_write ""
    _nds_realize_diag_write "=== disk: ${disk:-unknown} ==="
    [[ -n "$disk" ]] || return 0
    lsblk -f "$disk" >>"${ _nds_realize_diag_log; }" 2>&1 || true
    command -v parted &>/dev/null && parted "$disk" print >>"${ _nds_realize_diag_log; }" 2>&1 || true
    blkid "${disk}"* >>"${ _nds_realize_diag_log; }" 2>&1 || true
}

# Description: Single compact install-state snapshot (deduped per reason).
# Arguments:
# - reason: <String> Why this snapshot was taken
nds_realize_diag_snapshot() {
    local reason="${1:-snapshot}"
    local root disk loader uefi firmware profile_txt grub_txt mbr_txt nixos_sys uri free_mb

    [[ "${_NDS_REALIZE_DIAG_LAST_KEY}" == "$reason" ]] && return 0
    _NDS_REALIZE_DIAG_LAST_KEY="$reason"

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    disk="$(nds_cfg_get DISK_TARGET 2>/dev/null || true)"
    loader="$(nds_cfg_get BOOT_LOADER 2>/dev/null || true)"
    uefi="$(nds_cfg_get BOOT_UEFI_MODE 2>/dev/null || true)"
    [[ -d /sys/firmware/efi/efivars ]] && firmware=UEFI || firmware=BIOS

    if nixos_systemProfileOk "$root"; then
        profile_txt=$(env NIX_CONFIG="${ nixos_installNixConfig; }" \
            nix --store "$root" path-info -M /nix/var/nix/profiles/system 2>/dev/null || echo ok)
        profile_txt="${profile_txt} ($(ls -la "${root}/nix/var/nix/profiles/system" 2>/dev/null || echo no-symlink))"
    else
        profile_txt=missing
    fi
    [[ -e "${root}/boot/grub/grub.cfg" ]] && grub_txt=present || grub_txt=missing

    if [[ -n "$disk" && -b "$disk" ]]; then
        if dd if="$disk" bs=512 count=1 status=none 2>/dev/null | grep -aq GRUB; then
            mbr_txt=mbr
        elif disk_grubBiosBootOk "$disk"; then
            mbr_txt=bios_grub
        else
            mbr_txt=no
        fi
    else
        mbr_txt=unknown
    fi

    nixos_sys=$(ls -dt "${root}"/nix/store/*-nixos-system-*/ 2>/dev/null | head -1 || true)
    [[ -z "$nixos_sys" ]] && nixos_sys=none
    free_mb="${ nixos_storeFreeMb 2>/dev/null || echo unknown; }"
    uri="${ nixos_installStoreUri 2>/dev/null || echo iso; }"

    _nds_realize_diag_write ""
    _nds_realize_diag_write "=== ${reason} @ $(date -Iseconds 2>/dev/null || date) ==="
    _nds_realize_diag_kv "live_firmware" "$firmware"
    _nds_realize_diag_kv "BOOT_UEFI_MODE" "${uefi:-unset}"
    _nds_realize_diag_kv "BOOT_LOADER" "${loader:-unset}"
    _nds_realize_diag_kv "DISK_TARGET" "${disk:-unset}"
    _nds_realize_diag_kv "install_store_uri" "$uri"
    _nds_realize_diag_kv "iso_store_free_mb" "$free_mb"
    _nds_realize_diag_kv "mnt_mounted" "$(mountpoint -q "$root" 2>/dev/null && echo yes || echo no)"
    _nds_realize_diag_kv "mnt_boot_mounted" "$(mountpoint -q "${root}/boot" 2>/dev/null && echo yes || echo no)"
    _nds_realize_diag_kv "system_profile" "$profile_txt"
    _nds_realize_diag_kv "run_current_system" "$(ls -la "${root}/run/current-system" 2>&1 || echo missing)"
    _nds_realize_diag_kv "grub_cfg" "$grub_txt"
    _nds_realize_diag_kv "mbr_grub_sig" "$mbr_txt"
    _nds_realize_diag_kv "nixos_system" "$nixos_sys"

    if command -v findmnt &>/dev/null; then
        _nds_realize_diag_write "findmnt:"
        findmnt -R "$root" >>"${ _nds_realize_diag_log; }" 2>&1 || true
    fi
}

# Description: Snapshot after partition/disko.
# Arguments:
# - disk: <String> Block device
nds_realize_diag_after_partition() {
    nds_realize_diag_disk "${1:-}"
    nds_realize_diag_snapshot "after partition"
}

# Description: Snapshot when a step fails (hooked by nds_step_exec_to); appends the log tail.
# Arguments:
# - step_label: <String> Failed step name
nds_realize_diag_step_failure() {
    local step_label="$1"
    local verbose="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local line

    case "$step_label" in
        *NixOS*|*nixos-anywhere*|*Checking*) verbose="${NDS_NIXOS_INSTALL_LOG:-$verbose}" ;;
    esac
    nds_realize_diag_snapshot "FAILED: ${step_label}"
    [[ -f "$verbose" ]] || return 0
    _nds_realize_diag_write ""
    _nds_realize_diag_write "=== log tail (${verbose}) ==="
    while IFS= read -r line; do
        _nds_realize_diag_write "$line"
    done < <(tail -n 40 "$verbose" 2>/dev/null || true)
}
