#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install pre-flight checks
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-07-07
# Description:   Disk, nix, and boot checks before destructive install steps
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_PREFLIGHT_WARN_SKIP

# Description: Verify nix tooling, target disk, and boot mode before install.
# Git SSH access is verified earlier by flake gate / nds_git_access_run / closure checks.
# Arguments:
# - disk: <String|optional> Target block device
nds_preflight_install() {
    local disk="${1:-}"
    local uefi="${2:-}"
    local bootloader="${3:-}"

    if [[ -z "$uefi" || -z "$bootloader" ]]; then
        nds_install_ctx_ensure
        [[ -z "$uefi" ]] && uefi="${NDS_CTX_BOOT_UEFI_MODE:-}"
        [[ -z "$bootloader" ]] && bootloader="${NDS_CTX_BOOT_LOADER:-}"
    fi

    if ! command -v nix &>/dev/null; then
        error "nix not found — boot the NixOS live ISO"
        return 1
    fi

    if ! command -v nixos-install &>/dev/null; then
        error "nixos-install not found — boot the NixOS live ISO"
        return 1
    fi

    if [[ -n "$disk" ]]; then
        if [[ ! -b "$disk" ]]; then
            error "Target disk not found: $disk"
            return 1
        fi
    fi

    if [[ "$uefi" != "true" && "$bootloader" == "systemd-boot" ]]; then
        error "systemd-boot requires UEFI — pick GRUB in Boot settings or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" != "true" && "$bootloader" == "refind" ]]; then
        error "rEFInd requires UEFI — pick GRUB in Boot settings or enable UEFI mode"
        return 1
    fi

    if [[ "$uefi" == "true" && ! -d /sys/firmware/efi/efivars ]]; then
        warn "UEFI mode is on but the live ISO is BIOS-booted."
        warn "Reboot the ISO in UEFI mode, or disable UEFI mode and use GRUB."
        nds_install_ui_preflight_continue "Continue anyway?" || return 1
    fi

    return 0
}

# Description: Verify operator machine before remote nixos-anywhere install.
# Git SSH access is verified earlier by flake gate / nds_git_access_run / closure checks.
# Arguments:
# - target_ip: <String> Target host IP or hostname
nds_preflight_remote_install() {
    local target_ip="$1"

    if ! command -v nix &>/dev/null; then
        error "nix not found — install Nix on the operator machine"
        return 1
    fi

    if [[ -z "$target_ip" ]]; then
        error "REMOTE_TARGET_IP is required for remote install"
        return 1
    fi

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "root@${target_ip}" true 2>/dev/null; then
        debug "SSH reachable: root@${target_ip}"
    else
        warn "Cannot reach root@${target_ip} via SSH (passwordless root login required)"
        nds_install_ui_preflight_continue "Continue without verified SSH access?" || return 1
    fi

    return 0
}

# Description: Shallow-clone a flake for probing (disko detection, remote actions).
# Reuses the closure-phase clone when available.
# Arguments:
# - repo_url: <String> Git remote URL
# Returns:
# - <String> Flake root path (stdout)
nds_preflight_probe_flake() {
    local repo_url="$1"
    local probe_dir="${NDS_FLAKE_PROBE_REPO:-}"

    if [[ -f "${probe_dir}/flake.nix" ]]; then
        debug "Reusing session flake clone: ${probe_dir}"
        printf '%s\n' "$probe_dir"
        return 0
    fi

    if ! nds_git_clone_flake_probe "$repo_url"; then
        error "Could not clone $repo_url for probe"
        return 1
    fi

    printf '%s\n' "${NDS_FLAKE_PROBE_REPO}"
    return 0
}

# Description: Return true when host directory contains disko.nix.
# Arguments:
# - flake_root:   <String> Flake checkout root
# - host:         <String> nixosConfigurations name
# - host_dir_rel: <String> Host directory inside flake
nds_preflight_flake_has_disko() {
    local flake_root="$1"
    local host="$2"
    local host_dir_rel="${3:-hosts/x86_64-linux}"

    [[ -f "${flake_root}/${host_dir_rel}/${host}/disko.nix" ]] && return 0

    local found
    found=$(find "${flake_root}/${host_dir_rel}/${host}" -maxdepth 2 -name 'disko.nix' -print -quit 2>/dev/null || true)
    [[ -n "$found" ]] && return 0
    return 1
}

# Description: Suggest or set DISK_STRATEGY=flake when the flake owns disko.
# Arguments:
# - flake_root:   <String> Flake checkout root
# - host:         <String> nixosConfigurations name
# - host_dir_rel: <String> Host directory inside flake
nds_preflight_apply_disko_strategy() {
    local flake_root="$1"
    local host="$2"
    local host_dir_rel="${3:-hosts/x86_64-linux}"
    local current

    nds_install_ctx_ensure
    current="${NDS_CTX_DISK_STRATEGY:-nds}"

    if [[ "$current" != "nds" ]]; then
        return 0
    fi

    if ! nds_preflight_flake_has_disko "$flake_root" "$host" "$host_dir_rel"; then
        return 0
    fi

    info "Flake defines disko.nix for ${host} — switching DISK_STRATEGY to flake"
    nds_install_log "auto: DISK_STRATEGY=flake (flake has disko.nix)"
    CONFIG_DATA[DISK_STRATEGY]="flake"
    export NDS_DISK_STRATEGY="flake"
    NDS_CTX_DISK_STRATEGY="flake"
    return 0
}
