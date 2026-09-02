#!/usr/bin/env bash
# ==================================================================================================
# NDS - Post-install verification
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-27
# Description:   Verify partition mounts, hardware artifacts, bootloader, and system profile
# ==================================================================================================

declare -ga _NDS_INSTALL_VERIFY_FAILS=()

# Description: Record a failed verification check.
# Arguments:
# - message: <String> Human-readable failure description
_nds_install_verify_fail() {
    _NDS_INSTALL_VERIFY_FAILS+=("$1")
}

# Description: Verify GRUB is installed for BIOS/GPT layouts.
# Arguments:
# - disk: <String> Target block device
# Returns:
# - <Bool> 0 when GRUB boot code is present
_nds_install_verify_grub_bios() {
    local disk="$1"

    [[ -e /mnt/boot/grub/grub.cfg ]] || return 1
    _nds_install_grub_bios_boot_ok "$disk"
}

# Description: Verify UEFI bootloader files exist on the ESP.
# Arguments:
# - loader: <String> grub | systemd-boot | refind
# Returns:
# - <Bool> 0 when the expected EFI binary is present
_nds_install_verify_efi_files() {
    local loader="$1"

    case "$loader" in
        grub)
            local f
            for f in /mnt/boot/EFI/*/grub*.efi \
                /mnt/boot/EFI/nixos/grubx64.efi \
                /mnt/boot/EFI/BOOT/BOOTX64.EFI; do
                [[ -f "$f" ]] && return 0
            done
            return 1
            ;;
        refind)
            [[ -f /mnt/boot/EFI/refind/refind_x64.efi ]]
            ;;
        systemd-boot|*)
            [[ -f /mnt/boot/EFI/systemd/systemd-bootx64.efi ]]
            ;;
    esac
}

# Description: Verify bootloader artifacts match the configured preset.
# Arguments:
# - loader: <String> Bootloader id
# - uefi:   <String> true | false
# - disk:   <String> Target block device
_nds_install_verify_bootloader() {
    local loader="$1"
    local uefi="$2"
    local disk="$3"

    case "$loader" in
        systemd-boot)
            if [[ "$uefi" != "true" ]]; then
                _nds_install_verify_fail "systemd-boot requires UEFI mode"
                return 0
            fi
            _nds_install_verify_efi_files systemd-boot \
                || _nds_install_verify_fail "systemd-boot EFI binary missing on /mnt/boot"
            ;;
        refind)
            if [[ "$uefi" != "true" ]]; then
                _nds_install_verify_fail "rEFInd requires UEFI mode"
                return 0
            fi
            _nds_install_verify_efi_files refind \
                || _nds_install_verify_fail "rEFInd EFI binary missing on /mnt/boot"
            ;;
        grub|*)
            if [[ "$uefi" == "true" ]]; then
                _nds_install_verify_efi_files grub \
                    || _nds_install_verify_fail "GRUB EFI binary missing on /mnt/boot"
            else
                _nds_install_verify_grub_bios "$disk" \
                    || _nds_install_verify_fail "GRUB BIOS install missing (grub.cfg or ${disk} boot code)"
            fi
            ;;
    esac
}

# Description: Verify hardware artifact for flake installs.
# Arguments:
# - hostname: <String> Flake host name
_nds_install_verify_flake_hardware() {
    local hostname="$1"
    local hw_artifact host_dir_rel host_dir dest flake_root gen

    _nds_install_gather_flake_context
    [[ "$NDS_CTX_HW_PLACEMENT" != "skip" ]] || return 0

    hw_artifact=${ _nds_install_hardware_artifact_name; }
    host_dir_rel="$NDS_CTX_FLAKE_HOST_DIR"
    [[ -z "$host_dir_rel" ]] && host_dir_rel="hosts/x86_64-linux"
    flake_root="${NDS_FLAKE_ROOT:-$NDS_CTX_FLAKE_INSTALL_PATH}"

    case "$NDS_CTX_HW_PLACEMENT" in
        etc-nixos)
            dest="/mnt/etc/nixos/${hw_artifact}"
            ;;
        host-dir|*)
            dest="${flake_root}/${host_dir_rel}/${hostname}/${hw_artifact}"
            ;;
    esac

    if [[ ! -s "$dest" ]]; then
        _nds_install_verify_fail "Hardware artifact missing: ${dest}"
    fi

    host_dir="${flake_root}/${host_dir_rel}/${hostname}"
    gen="${host_dir}/nds_generated.nix"
    [[ -f "$gen" ]] || _nds_install_verify_fail "nds_generated.nix missing: ${gen}"
    grep -qE 'fileSystems|by-uuid|by-label' "$gen" \
        || _nds_install_verify_fail "nds_generated.nix missing fileSystems: ${gen}"
}

# Description: Verify classic-install artifacts on the target.
_nds_install_verify_classic_hardware() {
    local hw_artifact dest

    [[ -s /mnt/etc/nixos/configuration.nix ]] \
        || _nds_install_verify_fail "configuration.nix missing: /mnt/etc/nixos/configuration.nix"

    hw_artifact=${ _nds_install_hardware_artifact_name; }
    dest="/mnt/etc/nixos/${hw_artifact}"
    [[ -s "$dest" ]] || _nds_install_verify_fail "Hardware artifact missing: ${dest}"
}

# Description: Verify deploy keys + nds-git-ssh were installed when deploy keys exist.
_nds_install_verify_git_key() {
    local -a keys=()
    local key_path base dest wrap map_file switch_bin

    mapfile -t keys < <(_nds_git_collect_deploy_key_paths 2>/dev/null || true)
    # Only enforce nds_deploy_* — account/session keys are not copied to target.
    local -a deploy_keys=()
    for key_path in "${keys[@]}"; do
        [[ -f "$key_path" ]] || continue
        [[ "$(basename "$key_path")" == nds_deploy_* ]] || continue
        deploy_keys+=("$key_path")
    done
    [[ ${#deploy_keys[@]} -gt 0 ]] || return 0

    wrap="/mnt/var/lib/tcast/bin/tcast-git-ssh"
    map_file="/mnt/var/lib/tcast/git.map"
    switch_bin="/mnt/var/lib/tcast/bin/tcast"
    [[ -x "$wrap" ]] || _nds_install_verify_fail "tcast-git-ssh missing on target: ${wrap}"
    [[ -f "$map_file" ]] || _nds_install_verify_fail "git.map missing on target: ${map_file}"
    [[ -x "$switch_bin" ]] || _nds_install_verify_fail "tcast missing on target: ${switch_bin}"

    for key_path in "${deploy_keys[@]}"; do
        base="$(basename "$key_path")"
        dest="/mnt/root/.ssh/${base}"
        [[ -f "$dest" ]] || _nds_install_verify_fail "Git SSH key missing on target: ${dest}"
    done
}

# Description: Verify sops age key on target when the flake uses sops.
# Arguments:
# - flake_root: <String> Flake checkout path on the target
_nds_install_verify_sops() {
    local flake_root="$1"

    [[ -n "$flake_root" && -f "${flake_root}/.sops.yaml" ]] || return 0
    [[ -s /mnt/etc/sops/age/keys.txt ]] \
        || _nds_install_verify_fail "sops age key missing on target (.sops.yaml in flake)"
}

# Description: True when this session installed from a flake (not classic configuration.nix).
_nds_install_verify_is_flake() {
    local action kind
    if declare -f _nds_install_apply_kind &>/dev/null; then
        kind="${ _nds_install_apply_kind; }"
        [[ "$kind" == "flake" ]] && return 0
        [[ "$kind" == "classic" ]] && return 1
    fi
    action="${NDS_ACTION:-${NDS_CURRENT_ACTION:-}}"
    case "$action" in
        installFlake|remoteAction|addFleetHost|toolkit) return 0 ;;
        *) return 1 ;;
    esac
}

# Description: Verify a local install is bootable before bundle/reboot.
# Checks mounts, system profile, hardware artifacts, bootloader, and optional secrets.
# Returns:
# - <Bool> 0 when all checks pass
nds_install_verify_local() {
    local disk loader uefi encryption hostname flake_root

    _NDS_INSTALL_VERIFY_FAILS=()
    _nds_install_gather_context

    disk="$NDS_CTX_DISK"
    loader="${NDS_CTX_BOOT_LOADER:-grub}"
    uefi="$NDS_CTX_BOOT_UEFI_MODE"
    encryption="$NDS_CTX_ENCRYPTION"
    hostname="$NDS_CTX_HOSTNAME"
    flake_root="${NDS_FLAKE_ROOT:-}"

    log "Verifying installation (${loader}, $([[ "$uefi" == "true" ]] && echo UEFI || echo BIOS))"

    mountpoint -q /mnt \
        || _nds_install_verify_fail "Target root is not mounted at /mnt"

    _nds_install_nix_system_profile_ok /mnt \
        || _nds_install_verify_fail "NixOS system profile missing — nixos-install did not complete"

    if [[ "$encryption" == "true" ]]; then
        [[ -e /dev/mapper/cryptroot ]] \
            || _nds_install_verify_fail "Encrypted root device /dev/mapper/cryptroot is not available"
    else
        [[ -d /mnt/nix/store ]] \
            || _nds_install_verify_fail "Nix store missing on installed system (/mnt/nix/store)"
    fi

    mountpoint -q /mnt/boot \
        || _nds_install_verify_fail "Boot partition is not mounted at /mnt/boot"

    if _nds_install_verify_is_flake; then
        _nds_install_gather_flake_context
        flake_root="${flake_root:-$NDS_CTX_FLAKE_INSTALL_PATH}"
        _nds_install_verify_flake_hardware "$hostname"
        _nds_install_verify_sops "$flake_root"
    else
        _nds_install_verify_classic_hardware
    fi

    _nds_install_verify_bootloader "$loader" "$uefi" "$disk"
    _nds_install_verify_git_key

    if [[ ${#_NDS_INSTALL_VERIFY_FAILS[@]} -gt 0 ]]; then
        if declare -f nds_install_diag_snapshot &>/dev/null; then
            nds_install_diag_snapshot "verify failed: ${_NDS_INSTALL_VERIFY_FAILS[*]}"
        fi
        if declare -f nds_install_logs_fetch_hints &>/dev/null; then
            nds_install_logs_fetch_hints
        fi
        error "Installation verification failed (${#_NDS_INSTALL_VERIFY_FAILS[@]} issue(s)):"
        local issue
        for issue in "${_NDS_INSTALL_VERIFY_FAILS[@]}"; do
            error "  - ${issue}"
        done
        nds_install_log "verify: FAILED (${#_NDS_INSTALL_VERIFY_FAILS[@]} checks)"
        return 1
    fi

    success "Installation verification passed"
    nds_install_log "verify: all checks passed"
    return 0
}
