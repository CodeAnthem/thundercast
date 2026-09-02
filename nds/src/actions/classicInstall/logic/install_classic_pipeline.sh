#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install pipeline
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-14
# ==================================================================================================

# Description: Full classic NixOS install (disk prep + nixos-install).
nds_nixos_install() {
    _nds_install_gather_context
    nds_install_log "classicInstall: nds_nixos_install starting"
    nds_preflight_install "$NDS_CTX_DISK" "$NDS_CTX_BOOT_UEFI_MODE" "$NDS_CTX_BOOT_LOADER" || return 1

    NDS_UI_QUIET=true

    if ! nds_install_auto; then
        return 1
    fi

    # classic configuration.nix always imports ./hardware-configuration.nix
    _nds_install_classic_ensure_hardware_config || return 1

    nds_step_exec "Installing configuration files" _nds_install_configs || return 1
    nds_step_exec_nixos "Installing NixOS" _nds_install_nixos || return 1
    nds_step_exec "Registering EFI boot entry" _nds_install_register_efi_entry "$NDS_CTX_DISK" || return 1
    nds_step_exec "Verifying installation" nds_install_verify_local || return 1

    nds_install_log "classicInstall: completed"
    return 0
}
