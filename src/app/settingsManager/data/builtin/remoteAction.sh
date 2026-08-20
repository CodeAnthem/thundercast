#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote flake action preset
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-18
# ==================================================================================================

remoteAction_defaults() {
    [[ -n "$(nds_cfg_get CAST_REPO_URL)" ]] \
        || nds_cfg_set CAST_REPO_URL "${NDS_CAST_DEFAULT_URL:-https://github.com/CodeAnthem/thundercast.git}"
    [[ -n "$(nds_cfg_get CAST_ACTION)" ]] || nds_cfg_set CAST_ACTION ""
    nds_cfg_set CAST_TOOLKIT_MODE "new"
    nds_cfg_set CAST_TOOLKIT_BUNDLE ""
    nds_cfg_set FLAKE_REPO_URL ""
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    nds_cfg_set FLAKE_HOST ""
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
    nds_cfg_set SOPS_AGE_REUSE "generate"
    nds_cfg_set SOPS_AGE_KEY_FILE ""
}

remoteAction_configure() {
    nds_cfg_section_title "Install flake"
    nds_cfg_ask_url FLAKE_REPO_URL \
        "Install flake Git URL (your NixOS config repo)" "" true
}

remoteAction_summary() {
    local action
    action="$(nds_cfg_get CAST_ACTION)"
    [[ -n "$action" ]] && nds_cfg_summary_row "Remote action" "$action"
    nds_cfg_summary_row "Install flake" "$(nds_cfg_get FLAKE_REPO_URL)"
}

remoteAction_prompt_errors() {
    nds_cfg_section_title "Install flake"
    while ! remoteAction_validate &>/dev/null; do
        if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
            nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
            continue
        fi
        break
    done
}

remoteAction_validate() {
    [[ -n "$(nds_cfg_get CAST_REPO_URL)" ]] || { validation_error "Remote-action Git URL is required"; return 1; }
    [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]] || { validation_error "Install flake Git URL is required"; return 1; }
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=remoteAction_defaults \
        configure=remoteAction_configure \
        validate=remoteAction_validate \
        summary=remoteAction_summary \
        prompt_errors=remoteAction_prompt_errors
fi

NDS_PRESET_PRIORITY=20
NDS_PRESET_DISPLAY="Install flake"
