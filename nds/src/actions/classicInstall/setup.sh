#!/usr/bin/env bash
# ==================================================================================================
# NDS - Classic install action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-09-03
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

    if ! nds_sm_validate; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_sm_validate || exit 11
    fi

    nds_sm_menu || exit 12

    nds_cfg_set INSTALL_KIND "classic"
    nds_realize_run || exit $?
}
