#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install from flake action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-20
# Description:   Install a NixOS host from an existing flake via nixos-install --flake
# ==================================================================================================

# ----------------------------------------------------------------------------------
# Presets
# ----------------------------------------------------------------------------------

action_presets() {
    # platform (VM guest tools) is classicInstall-only — flake hosts use facter + flake modules
    printf '%s\n' installFlake boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display installFlake "Your flake"
    nds_cfg_preset_set_priority installFlake 20
    nds_cfg_preset_set_priority boot 21
    nds_cfg_preset_set_priority disk 22
    nds_cfg_preset_set_priority encryption 23
}

# ----------------------------------------------------------------------------------
# Preview
# ----------------------------------------------------------------------------------

action_preview() {
    nds_ui_h "Install NixOS from your flake"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "ask for flake URL (or path) and prove git access (root + flake.lock inputs)"
    nds_ui_i "list nixosConfigurations and let you pick a host"
    nds_ui_i "ask install mode / target disk (or remote IP)"
    nds_ui_i "open the settings manager for boot / disk / encryption"
    nds_ui_i "local: partition, facter, flake install — or remote: nixos-anywhere"
    nds_ui_b ""
}

# ----------------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------------

action_setup() {
    nds_mode_resolve || true

    # URL → git access → host pick → target, before the full settings menu.
    nds_app_actionHandler_logic_callFeature nds_flake_install_gate || exit 11

    if ! nds_sm_validate; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_sm_validate || exit 11
    fi

    nds_sm_menu || exit 12

    nds_cfg_set INSTALL_KIND "flake"
    nds_install_apply || exit $?
}
