#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - NDS toolkit create/restore action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-19
# Description:   Ops VM: operator age key, write leaf access, bundle zip
# ==================================================================================================

remote_action_prepare() {
    local mode
    if [[ -z "$(nds_cfg_get CAST_TOOLKIT_MODE 2>/dev/null || true)" ]]; then
        nds_cfg_set CAST_TOOLKIT_MODE "new"
    fi
    if ! nds_mode_is_unattended; then
        nds_cfg_section_title "Toolkit VM"
        nds_cfg_ask_choice CAST_TOOLKIT_MODE "Toolkit" "new|restore" \
            "new=Create operator key and deploy write access|restore=Inject a previous bundle zip" \
            "new"
    fi
    mode="$(nds_cfg_get CAST_TOOLKIT_MODE)"
    if [[ "$mode" == "restore" && -z "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)" ]]; then
        if nds_mode_is_unattended; then
            error "CAST_TOOLKIT_BUNDLE is required for toolkit restore"
            return 1
        fi
        nds_cfg_ask_path CAST_TOOLKIT_BUNDLE "Path to toolkit bundle zip" "" true
    fi
    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL 2>/dev/null || true)" ]]; then
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    fi
    if [[ -z "$(nds_cfg_get FLAKE_HOST 2>/dev/null || true)" ]] && ! nds_mode_is_unattended; then
        nds_cfg_ask_hostname FLAKE_HOST "Toolkit host name" "control-toolkit" true
    fi
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || nds_cfg_set FLAKE_HOST "control-toolkit"
    [[ -n "$(nds_cfg_get ENCRYPTION)" ]] || nds_cfg_set ENCRYPTION "false"
    [[ -n "$(nds_cfg_get DISK_STRATEGY)" ]] || nds_cfg_set DISK_STRATEGY "nds"
    nds_cfg_set SCAFFOLD_MODE "existing"
    return 0
}

remote_action_config() {
    local flake_root host
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    host="$(nds_cfg_get FLAKE_HOST)"
    nds_cfg_set NETWORK_HOSTNAME "$host"
    export NDS_FLAKE_HOST="$host"
    nds_flake_prepare
    return 0
}

remote_action_run() {
    local flake_root system host mode
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"
    host="$(nds_cfg_get FLAKE_HOST)"
    mode="$(nds_cfg_get CAST_TOOLKIT_MODE)"
    mode="${mode:-new}"

    [[ -n "$host" ]] || {
        error "Toolkit host name is empty"
        return 1
    }

    if [[ "$mode" == "restore" ]]; then
        nds_toolkit_restore_from_bundle "$(nds_cfg_get CAST_TOOLKIT_BUNDLE)" || return 1
        nds_toolkit_write_sops_policy "$flake_root" \
            "$(cat "$(_nds_toolkit_secrets_dir)/operator_age.pub")" || return 1
        mkdir -p "${flake_root}/.nds"
        cp "$(_nds_toolkit_secrets_dir)/operator_age.pub" "${flake_root}/.nds/operator.age.pub"
        [[ -f "$(_nds_toolkit_secrets_dir)/toolkit_ssh.pub" ]] \
            && cp "$(_nds_toolkit_secrets_dir)/toolkit_ssh.pub" "${flake_root}/.nds/toolkit.ssh.pub"
    else
        nds_toolkit_generate_operator "$flake_root" || return 1
    fi

    if [[ ! -d "${flake_root}/hosts/${system}/${host}" ]]; then
        error "Toolkit host ${host} is missing under hosts/${system}/ — add that host in the leaf first (no toolkit role/template)"
        return 1
    fi

    nds_flake_write_host_nds_env "$flake_root" "$host" || return 1
    nds_install_flake_run_hooks "$flake_root" post_scaffold || return 1

    nds_install_flake_commit_push_leaf "$flake_root" \
        "nds: toolkit ${mode} host ${host}" || return 1

    nds_install_flake_run_hooks "$flake_root" pre_install || return 1

    info "Installing toolkit host ${host}"
    nds_install_log "thundercast toolkit: host=${host} mode=${mode}"
    nds_nixos_install_flake || return 1

    nds_toolkit_install_keys_to_target /mnt || true
    nds_toolkit_ensure_cast_fetch_key /mnt || true
    nds_toolkit_seed_scripts_to_target /mnt || true
    nds_install_flake_run_hooks "$flake_root" post_install || return 1
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
    nds_ui_h "Create or restore the toolkit ops VM"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "install flake Git URL, toolkit host name, disk / encryption, guest tools"
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "use an existing hosts/ folder, write the operator pubkey, seed toolkitScripts, then flake-install"
    nds_ui_b ""
}
