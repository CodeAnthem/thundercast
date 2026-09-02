#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake install pipeline (action-level workflow)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-08-26
# Description:   installFlake action steps — uses install/flake helpers + git
# ==================================================================================================

# Description: Prepare flake env and verify git access to all flake inputs.
# Skips git re-check when the early gate already verified access this session.
# Arguments:
# - source: <String|optional> "remote" | "local" override for nds_flake_prepare
nds_flake_install_prepare_and_verify() {
    local source="${1:-}"
    local local_path repo_url

    nds_flake_prepare "$source"
    _nds_install_gather_flake_context
    repo_url="${ nds_install_ctx_get FLAKE_REPO_URL; }"
    local_path="${ nds_install_ctx_get FLAKE_LOCAL_PATH; }"

    if declare -f nds_git_access_verified &>/dev/null && nds_git_access_verified; then
        nds_install_log "git: access already verified this session — skip re-probe"
    else
        if [[ -n "$repo_url" ]]; then
            nds_app_actionManager_logic_callFeature nds_git_access_run \
                "FLAKE_REPO_URL=$repo_url" \
                read \
                "Clone the install flake and its private inputs." || return 1
        fi

        nds_install_ui_section_flake_access
        if [[ -n "$local_path" && -d "$local_path" ]]; then
            nds_git_ensure_flake_closure_access "$local_path" "$repo_url" || return 1
        elif [[ -n "$repo_url" ]]; then
            nds_git_ensure_flake_closure_access "" "$repo_url" || return 1
        fi
    fi

    nds_flake_detect_disko
    return 0
}

# Description: Preflight + confirm screen before flake install runs.
nds_flake_install_confirm() {
    local disk_strategy disk_target install_mode target_ip

    _nds_install_gather_flake_context
    disk_strategy="${ nds_install_ctx_get DISK_STRATEGY; }"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="${ nds_install_ctx_get DISK; }"
    install_mode="${ nds_install_ctx_get INSTALL_MODE; }"
    install_mode="${install_mode:-local}"
    target_ip="${ nds_install_ctx_get REMOTE_TARGET_IP; }"

    if [[ "$install_mode" == "remote" ]]; then
        nds_preflight_remote_install "$target_ip" || return 1
        nds_install_ui_confirm_remote "$target_ip" || return 1
    else
        nds_preflight_install "$disk_target" || return 1
        nds_install_ui_confirm_install "$disk_target" "$disk_strategy" || return 1
    fi
    return 0
}
