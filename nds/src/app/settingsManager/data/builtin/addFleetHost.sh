#!/usr/bin/env bash
# ==================================================================================================
# NDS - addFleetHost composer preset (scaffold a flake host from a leaf role)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-20
# ==================================================================================================

addFleetHost_defaults() {
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "addFleetHost"
    nds_cfg_set SCAFFOLD_MODE "new"
    nds_cfg_set SCAFFOLD_ROLE ""
    nds_cfg_set FLAKE_INSTALL_PATH "/mnt/etc/nixos"
    nds_cfg_set FLAKE_HOST_DIR "hosts/x86_64-linux"
    nds_cfg_set FLAKE_HARDWARE_PLACEMENT "host-dir"
    [[ -n "${ nds_cfg_get FLAKE_REPO_URL; }" ]] || nds_cfg_set FLAKE_REPO_URL ""
    [[ -n "${ nds_cfg_get FLAKE_HOST; }" ]] || nds_cfg_set FLAKE_HOST ""
}

addFleetHost_configure() {
    nds_cfg_section_title "Role host"
    nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    nds_cfg_ask_choice SCAFFOLD_MODE "Host" "new|existing" \
        "new=Scaffold from a .roles/ template|existing=Reuse a host folder already in the leaf" \
        "new"
}

addFleetHost_summary() {
    nds_cfg_summary_row "Install flake" "${ nds_cfg_get FLAKE_REPO_URL; }"
    nds_cfg_summary_row "Scaffold" "${ nds_cfg_get SCAFFOLD_MODE; }"
    local role host
    role="${ nds_cfg_get SCAFFOLD_ROLE; }"
    host="${ nds_cfg_get FLAKE_HOST; }"
    [[ -n "$role" ]] && nds_cfg_summary_row "Role" "$role"
    [[ -n "$host" ]] && nds_cfg_summary_row "Host" "$host"
}

addFleetHost_prompt_errors() {
    nds_cfg_section_title "Role host"
    while ! addFleetHost_validate &>/dev/null; do
        if [[ -z "${ nds_cfg_get FLAKE_REPO_URL; }" ]]; then
            nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
            continue
        fi
        break
    done
}

addFleetHost_validate() {
    [[ -n "${ nds_cfg_get FLAKE_REPO_URL; }" ]] || {
        validation_error "Install flake Git URL is required"
        return 1
    }
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=addFleetHost_defaults \
        configure=addFleetHost_configure \
        validate=addFleetHost_validate \
        summary=addFleetHost_summary \
        prompt_errors=addFleetHost_prompt_errors
fi

NDS_PRESET_PRIORITY=19
NDS_PRESET_DISPLAY="Role"
