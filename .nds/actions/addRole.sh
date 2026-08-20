#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - NDS addRole action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-19
# Description:   Scaffold + push a leaf host from .roles/, then flake-install
# ==================================================================================================

remote_action_prepare() {
    local default_url=""
    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)" ]]; then
        if nds_mode_is_unattended; then
            return 0
        fi
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "$default_url" true
    fi
    return 0
}

action_presets() {
    printf '%s\n' remoteAction network boot disk encryption platform
}

action_config() {
    nds_cfg_preset_set_display remoteAction "Install flake"
    nds_cfg_preset_set_priority remoteAction 20
    nds_cfg_preset_set_priority network 21
    nds_cfg_preset_set_priority boot 22
    nds_cfg_preset_set_priority disk 23
    nds_cfg_preset_set_priority encryption 24
    nds_cfg_preset_set_priority platform 25
}

action_preview() {
    nds_ui_h "Scaffold a host from a leaf role, then flake-install"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "install flake Git URL, hostname (Network), disk / encryption, guest tools"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "clone the install flake, pick a role, review settings once, then flake-install"
    nds_ui_i "leaf git key must be able to push (write deploy key or account key)"
    nds_ui_b ""
}

remote_action_config() {
    local flake_root system
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"

    if ! nds_flake_role_select "$flake_root" "$system"; then
        error "Leaf has no .roles/ (or profiles/) — copy thundercast/exampleRepo"
        return 1
    fi
    nds_flake_prepare
    return 0
}

remote_action_run() {
    local flake_root system role host mode
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"
    host="$(nds_cfg_get FLAKE_HOST)"
    role="$(nds_cfg_get SCAFFOLD_ROLE)"
    mode="$(nds_cfg_get SCAFFOLD_MODE)"
    mode="${mode:-new}"

    [[ -n "$host" ]] || {
        error "Host name is empty — pick a host in the remote action prompts"
        return 1
    }

    if [[ "$mode" == "new" ]]; then
        nds_flake_scaffold_apply "$flake_root" "$system" || return 1
    fi

    nds_flake_write_host_nds_env "$flake_root" "$host" || return 1
    nds_install_flake_run_hooks "$flake_root" post_scaffold || return 1

    nds_install_flake_commit_push_leaf "$flake_root" \
        "nds: ${mode} host ${host}${role:+ (role ${role})}" || return 1

    nds_install_flake_run_hooks "$flake_root" pre_install || return 1

    info "Installing leaf host ${host}${role:+ (role ${role})}"
    nds_install_log "thundercast addRole: host=${host} role=${role} mode=${mode}"
    nds_nixos_install_flake || return 1

    nds_install_flake_run_hooks "$flake_root" post_install || return 1
    return 0
}
