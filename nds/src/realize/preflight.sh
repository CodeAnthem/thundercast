#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - pre-flight checks before destructive steps
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-03
# Description:   Tooling, disk presence, boot-mode consistency. Git access is compose's job.
# ==================================================================================================

# Description: Verify nix tooling, target disk, and boot mode for a local install.
# Arguments:
# - disk:   <String> Target block device (may be empty for flake-owned disks)
# - uefi:   <String> BOOT_UEFI_MODE (true | false | "")
# - loader: <String> BOOT_LOADER id
nds_realize_preflight_local() {
    local disk="${1:-}"
    local uefi="${2:-}"
    local loader="${3:-}"

    command -v nix &>/dev/null || { error "nix not found — boot the NixOS live ISO"; return 1; }
    command -v nixos-install &>/dev/null || { error "nixos-install not found — boot the NixOS live ISO"; return 1; }

    if [[ -n "$disk" && ! -b "$disk" ]]; then
        error "Target disk not found: $disk"
        return 1
    fi
    if [[ "$uefi" != "true" && "$loader" == "systemd-boot" ]]; then
        error "systemd-boot requires UEFI — pick GRUB in Boot settings or enable UEFI mode"
        return 1
    fi
    if [[ "$uefi" != "true" && "$loader" == "refind" ]]; then
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

# Description: Verify operator machine before a remote nixos-anywhere install.
# Arguments:
# - target_ip: <String> Target host IP or hostname
nds_realize_preflight_remote() {
    local target_ip="$1"

    command -v nix &>/dev/null || { error "nix not found — install Nix on the operator machine"; return 1; }
    [[ -n "$target_ip" ]] || { error "REMOTE_TARGET_IP is required for remote install"; return 1; }

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
        "root@${target_ip}" true 2>/dev/null; then
        debug "SSH reachable: root@${target_ip}"
    else
        warn "Cannot reach root@${target_ip} via SSH (passwordless root login required)"
        nds_install_ui_preflight_continue "Continue without verified SSH access?" || return 1
    fi
    return 0
}
