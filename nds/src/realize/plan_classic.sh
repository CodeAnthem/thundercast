#!/usr/bin/env bash
# ==================================================================================================
# NDS realize - classic plan (generated configuration.nix + nixos-install)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-09-03
# ==================================================================================================

# Description: Classic recipe. Reads settings once; each step is a utility call with arguments.
# Returns:
# - <Int> 0 on success; 14 config files, 15 install
_nds_realize_plan_classic() {
    local disk strategy encryption remote_unlock loader uefi secrets_dir

    disk="$(nds_cfg_get DISK_TARGET)"
    strategy="$(nds_cfg_get DISK_STRATEGY)"; strategy="${strategy:-nds}"
    encryption="$(nds_cfg_get ENCRYPTION)"
    remote_unlock="$(nds_cfg_get ENCRYPTION_REMOTE_UNLOCK)"
    loader="$(nds_cfg_get BOOT_LOADER)"; loader="${loader:-grub}"
    uefi="$(nds_cfg_get BOOT_UEFI_MODE)"
    secrets_dir="${NDS_RUNTIME_DIR}/secrets"

    nds_requireUtility nixos || return 15
    nixos_setBootContext "$loader" "$uefi" "$disk" "$encryption"
    NDS_UI_QUIET=true

    nds_step_exec "Generating access secrets" _nds_realize_write_admin_password "$secrets_dir" || return 14
    nds_step_exec "Generating configuration.nix" nds_nixcfg_write_classic || return 14

    _nds_realize_disk_prepare "$disk" "$strategy" "$encryption" "$remote_unlock" "$uefi" "$loader" || return 15
    nds_step_exec "Generating hardware configuration" \
        _nds_realize_classic_hardware "/mnt/etc/nixos" "${NDS_RUNTIME_DIR}/config" || return 15

    nds_step_exec "Installing configuration files" nixos_copyConfigs "${NDS_RUNTIME_DIR}/config" /mnt || return 15
    nds_step_exec_nixos "Installing NixOS" _nds_realize_nixos_classic || return 15
    nds_realize_diag_snapshot "after install"
    nds_step_exec "Registering EFI boot entry" _nds_realize_register_efi "$disk" "$uefi" "$loader" || return 15
    nds_step_exec "Verifying installation" nds_realize_verify classic "" || return 15
    return 0
}

# Description: nixos-install then profile/bootloader repair (one visible step).
_nds_realize_nixos_classic() {
    nixos_installClassic /mnt || return 1
    nixos_ensureInstallArtifacts || return 1
    return 0
}
