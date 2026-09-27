#!/usr/bin/env bash
# ==================================================================================================
# NDS - Cook verify
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Mounts, profile, hardware, bootloader. Reads the recipe array.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -ga _NDS_COOK_VERIFY_FAILS=()

_nds_cook_verify_fail() {
    _NDS_COOK_VERIFY_FAILS+=("$1")
    if declare -f nds_diagnose_append >/dev/null; then
        nds_diagnose_append "verify: $1" || true
    fi
}

_nds_cook_verify_boot() {
    local _ver_loader=$1 _ver_uefi=$2 _ver_disk=$3
    case "$_ver_loader" in
        systemd-boot|refind)
            [[ "$_ver_uefi" == true ]] || _nds_cook_verify_fail "${_ver_loader} requires UEFI mode"
            disk_efiFilesPresent "$_ver_loader" "${_NDS_TARGET_ROOT}/boot" \
                || _nds_cook_verify_fail "${_ver_loader} EFI binary missing on ${_NDS_TARGET_ROOT}/boot"
            ;;
        *)
            if [[ "$_ver_uefi" == true ]]; then
                disk_efiFilesPresent grub "${_NDS_TARGET_ROOT}/boot" \
                    || _nds_cook_verify_fail "GRUB EFI binary missing on ${_NDS_TARGET_ROOT}/boot"
            else
                if [[ -z "$_ver_disk" ]]; then
                    [[ -e "${_NDS_TARGET_ROOT}/boot/grub/grub.cfg" ]] \
                        || _nds_cook_verify_fail "GRUB BIOS install missing"
                else
                    { [[ -e "${_NDS_TARGET_ROOT}/boot/grub/grub.cfg" ]] && disk_grubBiosBootOk "$_ver_disk"; } \
                        || _nds_cook_verify_fail "GRUB BIOS install missing"
                fi
            fi
            ;;
    esac
}

nds_cook_verify() {
    local -n _R=$1
    local _ver_kind=$2
    local _ver_issue _ver_artifact _ver_dest _ver_host _ver_dir _ver_gen
    _NDS_COOK_VERIFY_FAILS=()
    mountpoint -q "$_NDS_TARGET_ROOT" || _nds_cook_verify_fail "Target root is not mounted at ${_NDS_TARGET_ROOT}"
    nixos_systemProfileOk "$_NDS_TARGET_ROOT" || _nds_cook_verify_fail "NixOS system profile missing"
    if [[ ${_R[ENCRYPTION]:-} == true ]]; then
        [[ -e /dev/mapper/cryptroot ]] || _nds_cook_verify_fail "Encrypted root is not open"
    else
        [[ -d "${_NDS_TARGET_ROOT}/nix/store" ]] || _nds_cook_verify_fail "Nix store missing on the installed system"
    fi
    mountpoint -q "${_NDS_TARGET_ROOT}/boot" || _nds_cook_verify_fail "Boot partition is not mounted at ${_NDS_TARGET_ROOT}/boot"
    if [[ "$_ver_kind" == flake ]]; then
        _ver_host=${_R[FLAKE_HOST]:-}
        _ver_dir="${_R[FLAKE_INSTALL_PATH]:-${_NDS_TARGET_ROOT}/etc/nixos}/${_R[FLAKE_HOST_DIR]:-hosts/x86_64-linux}/${_ver_host}"
        _ver_artifact=${ hwconfig_artifactName flake; }
        case "${_R[FLAKE_HARDWARE_PLACEMENT]:-host-dir}" in
            skip) ;;
            etc-nixos) _ver_dest="${_NDS_TARGET_ROOT}/etc/nixos/${_ver_artifact}" ;;
            *) _ver_dest="${_ver_dir}/${_ver_artifact}" ;;
        esac
        if [[ -n ${_ver_dest:-} ]]; then
            [[ -s "$_ver_dest" ]] || _nds_cook_verify_fail "Hardware artifact missing: ${_ver_dest}"
        fi
        _ver_gen="${_ver_dir}/nds_generated.nix"
        [[ -f "$_ver_gen" ]] || _nds_cook_verify_fail "nds_generated.nix missing: ${_ver_gen}"
    else
        [[ -s "${_NDS_TARGET_ROOT}/etc/nixos/configuration.nix" ]] \
            || _nds_cook_verify_fail "configuration.nix missing"
        [[ -s "${_NDS_TARGET_ROOT}/etc/nixos/hardware-configuration.nix" ]] \
            || _nds_cook_verify_fail "hardware-configuration.nix missing"
    fi
    _nds_cook_verify_boot "${_R[BOOT_LOADER]:-grub}" "${_R[BOOT_UEFI_MODE]:-}" "${_R[DISK_TARGET]:-}"
    if ((${#_NDS_COOK_VERIFY_FAILS[@]})); then
        for _ver_issue in "${_NDS_COOK_VERIFY_FAILS[@]}"; do
            error "verify: ${_ver_issue}"
        done
        return 1
    fi
}
