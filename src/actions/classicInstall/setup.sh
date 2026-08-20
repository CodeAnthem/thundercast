#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-16
# Description:   Install NixOS with a generated /etc/nixos configuration (no flake needed)
# ==================================================================================================

# ----------------------------------------------------------------------------------
# Presets
# ----------------------------------------------------------------------------------

action_presets() {
    printf '%s\n' quick region network boot access disk encryption platform
}

# no-op: builtin titles/priorities
action_config() {
    :
}

# ----------------------------------------------------------------------------------
# Preview
# ----------------------------------------------------------------------------------

action_preview() {
    nds_ui_h "Classic NixOS installation (no flake required)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "timezone, locales, keyboard, network, admin user"
    nds_ui_i "bootloader and disk"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "1. partition the target disk (and set up LUKS2 if encryption is enabled)"
    nds_ui_i "2. generate configuration.nix and hardware-configuration.nix"
    nds_ui_i "3. run nixos-install (Nix downloads and builds packages)"
    nds_ui_i "4. offer an install backup zip, then reboot"
    nds_ui_b ""
}

# ----------------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------------

action_setup() {
    nds_mode_resolve || true

    if ! nds_cfg_validate_all; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_cfg_validate_all || exit 11
    fi

    nds_cfg_menu_or_skip || exit 12

    local disk_strategy disk_target
    disk_strategy="$(nds_cfg_get "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_cfg_get "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11
    nds_install_ui_confirm_install "$disk_target" "$disk_strategy" || exit 13

    nds_install_ui_section_nixos_install
    nds_install_log "classicInstall: action starting"

    NDS_UI_QUIET=true
    nds_step_exec "Generating access secrets" _nds_install_generate_access_secrets || exit 14
    nds_step_exec "Generating configuration.nix" nds_nixcfg_write_classic || exit 14

    nds_nixos_install || exit 15
    nds_install_finish || exit 16
}
