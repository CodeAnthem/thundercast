#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - post-install verification (mounts, profile, hardware, bootloader, keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-09-03
# ==================================================================================================

declare -ga _NDS_REALIZE_VERIFY_FAILS=()

_nds_realize_verify_fail() {
    _NDS_REALIZE_VERIFY_FAILS+=("$1")
}

# Description: Bootloader artifacts must match the configured preset.
# Arguments:
# - loader: <String> Bootloader id
# - uefi:   <String> true | false
# - disk:   <String> Target block device
_nds_realize_verify_bootloader() {
    local loader="$1" uefi="$2" disk="$3"

    case "$loader" in
        systemd-boot|refind)
            if [[ "$uefi" != "true" ]]; then
                _nds_realize_verify_fail "${loader} requires UEFI mode"
                return 0
            fi
            disk_efiFilesPresent "$loader" /mnt/boot \
                || _nds_realize_verify_fail "${loader} EFI binary missing on /mnt/boot"
            ;;
        grub|*)
            if [[ "$uefi" == "true" ]]; then
                disk_efiFilesPresent grub /mnt/boot \
                    || _nds_realize_verify_fail "GRUB EFI binary missing on /mnt/boot"
            else
                { [[ -e /mnt/boot/grub/grub.cfg ]] && disk_grubBiosBootOk "$disk"; } \
                    || _nds_realize_verify_fail "GRUB BIOS install missing (grub.cfg or ${disk} boot code)"
            fi
            ;;
    esac
}

# Description: Flake: hardware artifact + nds_generated.nix present for the host.
# Arguments:
# - flake_root: <String> Flake checkout on the target
# - host:       <String> Host name
_nds_realize_verify_flake_host() {
    local flake_root="$1" host="$2"
    local hw_placement host_dir_rel artifact host_dir dest gen

    hw_placement="$(nds_cfg_get FLAKE_HARDWARE_PLACEMENT)"; hw_placement="${hw_placement:-host-dir}"
    host_dir_rel="$(nds_cfg_get FLAKE_HOST_DIR)"; host_dir_rel="${host_dir_rel:-hosts/x86_64-linux}"
    host_dir="${flake_root}/${host_dir_rel}/${host}"
    artifact=${ _nds_realize_hw_artifact_name; }

    if [[ "$hw_placement" != "skip" ]]; then
        case "$hw_placement" in
            etc-nixos) dest="/mnt/etc/nixos/${artifact}" ;;
            host-dir|*) dest="${host_dir}/${artifact}" ;;
        esac
        [[ -s "$dest" ]] || _nds_realize_verify_fail "Hardware artifact missing: ${dest}"
    fi

    gen="${host_dir}/nds_generated.nix"
    [[ -f "$gen" ]] || _nds_realize_verify_fail "nds_generated.nix missing: ${gen}"
    grep -qE 'fileSystems|by-uuid|by-label' "$gen" 2>/dev/null \
        || _nds_realize_verify_fail "nds_generated.nix missing fileSystems: ${gen}"
    [[ -n "$flake_root" && -f "${flake_root}/.sops.yaml" ]] || return 0
    [[ -s /mnt/etc/sops/age/keys.txt ]] \
        || _nds_realize_verify_fail "sops age key missing on target (.sops.yaml in flake)"
}

# Description: Classic: configuration.nix + hardware-configuration.nix on the target.
_nds_realize_verify_classic_host() {
    [[ -s /mnt/etc/nixos/configuration.nix ]] \
        || _nds_realize_verify_fail "configuration.nix missing: /mnt/etc/nixos/configuration.nix"
    [[ -s /mnt/etc/nixos/hardware-configuration.nix ]] \
        || _nds_realize_verify_fail "Hardware artifact missing: /mnt/etc/nixos/hardware-configuration.nix"
}

# Description: Deploy keys + tcast helpers landed on the target (when deploy keys exist).
_nds_realize_verify_git_keys() {
    local -a keys=() deploy_keys=()
    local key_path base

    mapfile -t keys < <(_nds_git_collect_deploy_key_paths 2>/dev/null || true)
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" && "$(basename "$key_path")" == nds_deploy_* ]] && deploy_keys+=("$key_path")
    done
    [[ ${#deploy_keys[@]} -gt 0 ]] || return 0

    [[ -x /mnt/var/lib/tcast/bin/tcast-git-ssh ]] || _nds_realize_verify_fail "tcast-git-ssh missing on target"
    [[ -f /mnt/var/lib/tcast/git.map ]] || _nds_realize_verify_fail "git.map missing on target"
    [[ -x /mnt/var/lib/tcast/bin/tcast ]] || _nds_realize_verify_fail "tcast missing on target"
    for key_path in "${deploy_keys[@]}"; do
        base="$(basename "$key_path")"
        [[ -f "/mnt/root/.ssh/${base}" ]] || _nds_realize_verify_fail "Git SSH key missing on target: /mnt/root/.ssh/${base}"
    done
}

# Description: Verify the local install is bootable before bundle/reboot.
# Arguments:
# - kind:       <String> classic | flake
# - flake_root: <String> Flake checkout on the target (flake only)
# Returns:
# - <Bool> 0 when every check passes
nds_realize_verify() {
    local kind="$1" flake_root="${2:-}"
    local disk loader uefi encryption host issue

    _NDS_REALIZE_VERIFY_FAILS=()
    nds_requireUtility disk || return 1
    nds_requireUtility nixos || return 1
    disk="$(nds_cfg_get DISK_TARGET)"
    loader="$(nds_cfg_get BOOT_LOADER)"; loader="${loader:-grub}"
    uefi="$(nds_cfg_get BOOT_UEFI_MODE)"
    encryption="$(nds_cfg_get ENCRYPTION)"
    host="${ _nds_realize_flake_host; }"

    log "Verifying installation (${loader}, $([[ "$uefi" == "true" ]] && echo UEFI || echo BIOS))"

    mountpoint -q /mnt || _nds_realize_verify_fail "Target root is not mounted at /mnt"
    nixos_systemProfileOk /mnt || _nds_realize_verify_fail "NixOS system profile missing — install did not complete"
    if [[ "$encryption" == "true" ]]; then
        [[ -e /dev/mapper/cryptroot ]] || _nds_realize_verify_fail "Encrypted root /dev/mapper/cryptroot is not available"
    else
        [[ -d /mnt/nix/store ]] || _nds_realize_verify_fail "Nix store missing on installed system (/mnt/nix/store)"
    fi
    mountpoint -q /mnt/boot || _nds_realize_verify_fail "Boot partition is not mounted at /mnt/boot"

    if [[ "$kind" == "flake" ]]; then
        _nds_realize_verify_flake_host "$flake_root" "$host"
    else
        _nds_realize_verify_classic_host
    fi
    _nds_realize_verify_bootloader "$loader" "$uefi" "$disk"
    _nds_realize_verify_git_keys

    if [[ ${#_NDS_REALIZE_VERIFY_FAILS[@]} -gt 0 ]]; then
        nds_realize_diag_snapshot "verify failed: ${_NDS_REALIZE_VERIFY_FAILS[*]}"
        declare -f nds_install_logs_fetch_hints &>/dev/null && nds_install_logs_fetch_hints
        error "Installation verification failed (${#_NDS_REALIZE_VERIFY_FAILS[@]} issue(s)):"
        for issue in "${_NDS_REALIZE_VERIFY_FAILS[@]}"; do
            error "  - ${issue}"
        done
        nds_install_log "verify: FAILED (${#_NDS_REALIZE_VERIFY_FAILS[@]} checks)"
        return 1
    fi
    success "Installation verification passed"
    nds_install_log "verify: all checks passed"
    return 0
}
