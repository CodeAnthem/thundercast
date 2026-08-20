#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-29 | Modified: 2026-08-18
# Description:   Clone an action catalog (.nds/actions), then the install flake
# ==================================================================================================

# ----------------------------------------------------------------------------------
# Presets
# ----------------------------------------------------------------------------------

action_presets() {
    # platform is classicInstall-only — flake path uses facter + host modules
    printf '%s\n' remoteAction network boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display remoteAction "Install flake"
    nds_cfg_preset_set_priority remoteAction 20
    nds_cfg_preset_set_priority network 21
    nds_cfg_preset_set_priority boot 22
    nds_cfg_preset_set_priority disk 23
    nds_cfg_preset_set_priority encryption 24
}

# Extra preset files/dirs from NDS_PRESET_EXTRA_PATHS (colon-separated).
# NDS_PRESET_EXTRA_DIR is loaded by the action handler for every action.
action_presets_paths() {
    [[ -n "${NDS_PRESET_EXTRA_PATHS:-}" ]] && tr ':' '\n' <<< "$NDS_PRESET_EXTRA_PATHS"
}

# ----------------------------------------------------------------------------------
# Preview
# ----------------------------------------------------------------------------------

action_preview() {
    nds_ui_h "Run a remote action against your install flake"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "install flake Git URL, hostname (Network), disk / encryption"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "clone the install flake, run the remote action, then flake-install"
    nds_ui_i "reboot when done"
    nds_ui_b ""
}

# ----------------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------------

action_setup() {
    nds_mode_resolve || true

    local remote_script action_id
    local host_dir probe_dir injected=0
    local disk_strategy disk_target

    action_id="$(nds_cfg_get CAST_ACTION)"
    [[ -n "$action_id" ]] || {
        error "CAST_ACTION is empty — catalog gate did not pick an action"
        exit 14
    }

    if declare -f remote_action_prepare &>/dev/null; then
        remote_action_prepare || exit 14
    fi

    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
        if nds_mode_is_unattended; then
            error "FLAKE_REPO_URL is required (install flake Git URL)"
            exit 11
        fi
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    fi
    [[ -n "$(nds_cfg_get FLAKE_REPO_URL)" ]] || {
        error "Install flake Git URL is required"
        exit 11
    }

    nds_flake_prepare remote
    if ! nds_mode_is_unattended; then
        nds_ui_warn "This action git-pushes a new host to the install flake."
        nds_ui_warn "GitHub deploy keys are read-only unless \"Allow write access\" is enabled."
        nds_ui_warn "Use an account key, or a write-enabled deploy key — not a read-only backup."
        nds_ui_b ""
    fi
    nds_app_actionHandler_logic_callFeature nds_git_access_run \
        "FLAKE_REPO_URL=$(nds_cfg_get FLAKE_REPO_URL)" || exit 14

    host_dir="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"

    nds_step_start "Cloning install flake"
    probe_dir=$(nds_preflight_probe_flake "$(nds_cfg_get FLAKE_REPO_URL)") || exit 14
    nds_step_complete "Install flake cloned"
    export NDS_FLAKE_PROBE_DIR="$probe_dir"

    nds_preset_inject_from_flake "$probe_dir" || true
    injected=$NDS_PRESET_INJECT_COUNT
    if [[ "${injected:-0}" -gt 0 ]]; then
        info "Loaded ${injected} custom preset(s) from flake .nds/"
    fi

    nds_preflight_apply_disko_strategy "$probe_dir" "${NDS_FLAKE_HOST}" "$host_dir"

    nds_step_start "Verifying git input access"
    nds_git_ensure_flake_closure_access "$probe_dir" "$(nds_cfg_get FLAKE_REPO_URL)" || exit 14
    nds_step_complete "Git input access OK"

    nds_step_start "Verifying leaf write access"
    nds_install_flake_probe_leaf_write "$probe_dir" || exit 14
    nds_step_complete "Leaf write access OK"

    if [[ "$action_id" != "toolkit" && -f "${probe_dir}/.nds/action.sh" ]]; then
        info "Leaf .nds/action.sh override — sourcing instead of catalog action"
        nds_import_file "${probe_dir}/.nds/action.sh" || exit 14
        remote_script="${probe_dir}/.nds/action.sh"
    fi

    if declare -f remote_action_config &>/dev/null; then
        remote_action_config || exit 14
    fi
    nds_cfg_menu_or_skip || exit 12
    if declare -f remote_action_config &>/dev/null; then
        nds_flake_prepare remote
        nds_preflight_apply_disko_strategy "$probe_dir" "$(nds_cfg_get FLAKE_HOST)" "$host_dir"
    fi

    disk_strategy="$(nds_cfg_get "DISK_STRATEGY")"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_cfg_get "DISK_TARGET")"

    nds_preflight_install "$disk_target" || exit 11
    nds_install_ui_confirm_install "$disk_target" "$disk_strategy" || exit 13

    if declare -f remote_action_run &>/dev/null; then
        nds_install_log "remoteAction: running ${action_id}"
        remote_action_run || exit 15
    else
        error "Remote action must define remote_action_run"
        exit 14
    fi

    export NDS_GIT_INSTALL_SUCCEEDED=true
    nds_git_access_cleanup_success
    nds_install_finish || exit 16
}
