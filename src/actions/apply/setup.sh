#!/usr/bin/env bash
# ==================================================================================================
# NDS - Apply recipe action (Part A only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# Description:   Install NixOS from a complete recipe file (no composer wizard)
# ==================================================================================================

action_presets() {
    printf '%s\n' quick region network boot access disk encryption platform
}

action_config() {
    nds_cfg_set INSTALL_COMPOSER "apply"
}

action_preview() {
    nds_ui_h "Apply a complete NDS recipe"
    nds_ui_b ""
    nds_ui_b "Part A only — no settings wizard. The recipe must already be valid."
    nds_ui_b ""
    nds_ui_b "Pass a file with --recipe PATH, NDS_RECIPE_FILE, or set keys via NDS_* env."
    nds_ui_b "Secret values stay in files: ACCESS_ADMIN_PASSWORD_FILE, ENCRYPTION_PASSPHRASE_FILE."
    nds_ui_b ""
}

action_setup() {
    nds_mode_resolve || true

    if [[ -n "${NDS_RECIPE_FILE:-}" ]]; then
        nds_sm_load "$NDS_RECIPE_FILE" || exit 11
    fi

    if [[ "$(_nds_install_apply_kind)" == "flake" ]]; then
        if [[ "${PRESET_LOADED[installFlake]:-}" != "1" ]]; then
            nds_preset_load_file "${SCRIPT_DIR}/app/settingsManager/data/builtin/installFlake.sh" || exit 11
        fi
        nds_cfg_preset_enable installFlake
        nds_cfg_seed_new_presets
        nds_cfg_set INSTALL_KIND "flake"
    else
        nds_cfg_set INSTALL_KIND "classic"
    fi

    if ! nds_sm_validate; then
        error "Recipe is incomplete or invalid — fix it or run a composer (classicInstall / installFlake / addRole / toolkit)"
        exit 11
    fi

    nds_install_apply || exit $?
}
