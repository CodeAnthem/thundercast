#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action (user catalog only)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-20
# Description:   Clone a user action catalog, run its composer, then Part A install
# ==================================================================================================

action_presets() {
    printf '%s\n' remoteAction network boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display remoteAction "Install flake"
    nds_cfg_preset_set_priority remoteAction 20
    nds_cfg_preset_set_priority network 21
    nds_cfg_preset_set_priority boot 22
    nds_cfg_preset_set_priority disk 23
    nds_cfg_preset_set_priority encryption 24
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "remoteAction"
}

action_presets_paths() {
    [[ -n "${NDS_PRESET_EXTRA_PATHS:-}" ]] && tr ':' '\n' <<< "$NDS_PRESET_EXTRA_PATHS"
}

action_preview() {
    nds_ui_h "Run a custom action from your catalog"
    nds_ui_b ""
    nds_ui_b "Built-in toolkit and addFleetHost are NDS actions — not catalog scripts."
    nds_ui_b "A remote action may define extra presets, compose host files, and register hooks."
    nds_ui_b "Disk confirm happens before compose. Part A then partitions and flake-installs."
    nds_ui_b ""
}

action_setup() {
    nds_mode_resolve || true

    local action_id host_dir
    action_id="${ nds_cfg_get CAST_ACTION; }"
    [[ -n "$action_id" ]] || {
        error "CAST_ACTION is empty — catalog gate did not pick an action"
        exit 14
    }

    case "$action_id" in
        toolkit|addFleetHost)
            error "${action_id} is a built-in NDS action (NDS_ACTION=${action_id}), not a catalog script"
            exit 14
            ;;
    esac

    if declare -f remote_action_prepare &>/dev/null; then
        remote_action_prepare || exit 14
    fi

    if [[ -z "${ nds_cfg_get FLAKE_REPO_URL; }" ]]; then
        if nds_mode_is_unattended; then
            error "FLAKE_REPO_URL is required (install flake Git URL)"
            exit 11
        fi
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    fi
    [[ -n "${ nds_cfg_get FLAKE_REPO_URL; }" ]] || {
        error "Install flake Git URL is required"
        exit 11
    }

    nds_install_open_leaf || exit 14

    host_dir="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"
    if [[ -f "${NDS_FLAKE_PROBE_DIR}/.nds/action.sh" ]]; then
        info "Leaf .nds/action.sh override — sourcing instead of catalog action"
        nds_import_file "${NDS_FLAKE_PROBE_DIR}/.nds/action.sh" || exit 14
    fi

    if declare -f remote_action_config &>/dev/null; then
        remote_action_config || exit 14
        nds_flake_prepare remote
        nds_preflight_apply_disko_strategy "$NDS_FLAKE_PROBE_DIR" "${ nds_cfg_get FLAKE_HOST; }" "$host_dir"
    fi
    nds_cfg_menu_or_skip || exit 12
    nds_install_confirm || exit 13

    NDS_REMOTE_ACTION_DID_INSTALL=0
    export NDS_REMOTE_ACTION_DID_INSTALL
    if declare -f remote_action_run &>/dev/null; then
        nds_install_log "remoteAction: composing ${action_id}"
        remote_action_run || exit 15
    else
        error "Remote action must define remote_action_run (compose only — do not nixos-install)"
        exit 14
    fi

    if [[ "${NDS_REMOTE_ACTION_DID_INSTALL}" != "1" ]]; then
        nds_cfg_set INSTALL_KIND "flake"
        nds_install_apply || exit $?
    else
        export NDS_GIT_INSTALL_SUCCEEDED=true
        nds_git_access_cleanup_success
        nds_install_finish || exit 16
    fi

    if declare -f remote_action_after &>/dev/null; then
        remote_action_after || exit 15
    fi
}
