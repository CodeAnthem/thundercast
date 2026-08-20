#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install diagnostics (compact log, separate from nixos-install output)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-14
# Description:   Structured install state in NDS_INSTALL_DIAG_LOG (folded into nds.log)
# ==================================================================================================

declare -g _NDS_INSTALL_DIAG_LAST_KEY=""

# Description: Path to the compact diagnostics log.
# Returns:
# - <String> log file path (stdout)
_nds_install_diag_log() {
    printf '%s\n' "${NDS_INSTALL_DIAG_LOG:-/tmp/nds_install_diag.log}"
}

# Description: Append one line to the diagnostics log.
# Arguments:
# - line: <String> Log line
_nds_install_diag_write() {
    local line="$1"
    printf '%s\n' "$line" >>"$(_nds_install_diag_log)"
}

# Description: Compact one-line or short multi-line fact.
# Arguments:
# - key:   <String> Fact name
# - value: <String> Fact value
_nds_install_diag_kv() {
    local key="$1"
    local value="$2"
    _nds_install_diag_write "${key}=${value}"
}

# Description: Disk layout summary (no command echo).
# Arguments:
# - disk: <String> Block device
nds_install_diag_disk() {
    local disk="${1:-}"

    _nds_install_diag_write ""
    _nds_install_diag_write "=== disk: ${disk:-unknown} ==="
    [[ -n "$disk" ]] || return 0
    lsblk -f "$disk" >>"$(_nds_install_diag_log)" 2>&1 || true
    if command -v parted &>/dev/null; then
        parted "$disk" print >>"$(_nds_install_diag_log)" 2>&1 || true
    fi
    blkid "${disk}"* >>"$(_nds_install_diag_log)" 2>&1 || true
}

# Description: Single compact install-state snapshot (deduped per reason).
# Arguments:
# - reason: <String> Why this snapshot was taken
nds_install_diag_snapshot() {
    local reason="${1:-snapshot}"
    local root disk loader uefi firmware
    local profile_txt grub_txt mbr_txt nixos_sys uri free_mb

    if [[ "${_NDS_INSTALL_DIAG_LAST_KEY}" == "$reason" ]]; then
        return 0
    fi
    _NDS_INSTALL_DIAG_LAST_KEY="$reason"

    root="${NDS_NIX_TARGET_ROOT:-/mnt}"
    nds_install_ctx_ensure
    disk="${NDS_CTX_DISK:-}"
    loader="${NDS_CTX_BOOT_LOADER:-}"
    uefi="${NDS_CTX_BOOT_UEFI_MODE:-}"
    if [[ -d /sys/firmware/efi/efivars ]]; then
        firmware=UEFI
    else
        firmware=BIOS
    fi

    if _nds_install_nix_system_profile_ok "$root"; then
        profile_txt=$(env NIX_CONFIG="$(_nds_install_nix_nixos_install_config)" \
            nix --store "$root" path-info -M /nix/var/nix/profiles/system 2>/dev/null || echo ok)
        profile_txt="${profile_txt} ($(ls -la "${root}/nix/var/nix/profiles/system" 2>/dev/null || echo no-symlink))"
    else
        profile_txt=missing
    fi

    if [[ -e "${root}/boot/grub/grub.cfg" ]]; then
        grub_txt=present
    else
        grub_txt=missing
    fi

    if [[ -n "$disk" && -b "$disk" ]]; then
        if dd if="$disk" bs=512 count=1 status=none 2>/dev/null | grep -aq GRUB; then
            mbr_txt=mbr
        elif _nds_install_disk_has_bios_grub "$disk" \
            && _nds_install_bios_grub_populated "${disk}1"; then
            mbr_txt=bios_grub
        else
            mbr_txt=no
        fi
    else
        mbr_txt=unknown
    fi

    nixos_sys=$(ls -dt "${root}"/nix/store/*-nixos-system-*/ 2>/dev/null | head -1 || true)
    [[ -z "$nixos_sys" ]] && nixos_sys=none
    free_mb="$(_nds_install_nix_store_free_mb 2>/dev/null || echo unknown)"
    uri="$(_nds_install_nix_install_store_uri 2>/dev/null || echo iso)"

    _nds_install_diag_write ""
    _nds_install_diag_write "=== ${reason} @ $(date -Iseconds 2>/dev/null || date) ==="
    _nds_install_diag_kv "live_firmware" "$firmware"
    _nds_install_diag_kv "BOOT_UEFI_MODE" "${uefi:-unset}"
    _nds_install_diag_kv "BOOT_LOADER" "${loader:-unset}"
    _nds_install_diag_kv "DISK_TARGET" "${disk:-unset}"
    _nds_install_diag_kv "install_store_uri" "$uri"
    _nds_install_diag_kv "iso_store_free_mb" "$free_mb"
    _nds_install_diag_kv "mnt_mounted" "$(mountpoint -q "$root" 2>/dev/null && echo yes || echo no)"
    _nds_install_diag_kv "mnt_boot_mounted" "$(mountpoint -q "${root}/boot" 2>/dev/null && echo yes || echo no)"
    _nds_install_diag_kv "system_profile" "$profile_txt"
    _nds_install_diag_kv "run_current_system" \
        "$(ls -la "${root}/run/current-system" 2>&1 || echo missing)"
    _nds_install_diag_kv "grub_cfg" "$grub_txt"
    _nds_install_diag_kv "mbr_grub_sig" "$mbr_txt"
    _nds_install_diag_kv "nixos_system" "$nixos_sys"

    if command -v findmnt &>/dev/null; then
        _nds_install_diag_write "findmnt:"
        findmnt -R "$root" >>"$(_nds_install_diag_log)" 2>&1 || true
    fi
}

# Description: Snapshot after partition/disko.
# Arguments:
# - disk: <String> Block device
nds_install_diag_after_partition() {
    local disk="${1:-}"
    nds_install_diag_disk "$disk"
    nds_install_diag_snapshot "after partition"
}

# Description: Snapshot after mounting target filesystems.
nds_install_diag_after_mount() {
    nds_install_diag_snapshot "after mount"
}

# Description: Snapshot when an install step fails (once, no duplicates).
# Appends the last lines of the verbose install log so the UI/diag show the real error.
# Arguments:
# - step_label: <String> Failed step name
nds_install_diag_step_failure() {
    local step_label="$1"
    local verbose="${NDS_INSTALL_DETAIL_LOG:-/tmp/nds_install.log}"
    local line

    case "$step_label" in
        *NixOS*|*nixos-anywhere*)
            verbose="${NDS_NIXOS_INSTALL_LOG:-$verbose}"
            ;;
    esac

    nds_install_diag_snapshot "FAILED: ${step_label}"

    if [[ -f "$verbose" ]]; then
        _nds_install_diag_write ""
        _nds_install_diag_write "=== log tail (${verbose}) ==="
        while IFS= read -r line; do
            _nds_install_diag_write "$line"
        done < <(tail -n 40 "$verbose" 2>/dev/null || true)
    fi
}
