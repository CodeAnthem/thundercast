#!/usr/bin/env bash
# ==================================================================================================
# NDS - toolkit composer (ops VM create/restore, then Part A)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-27
# Description:   First-class toolkit VM flow — not a remote catalog action
# ==================================================================================================

action_presets() {
    printf '%s\n' toolkit installFlake boot disk encryption
}

action_config() {
    nds_cfg_preset_set_display toolkit "Toolkit"
    nds_cfg_preset_set_priority toolkit 19
    nds_cfg_preset_set_priority installFlake 20
    nds_cfg_preset_set_priority boot 21
    nds_cfg_preset_set_priority disk 22
    nds_cfg_preset_set_priority encryption 23
    nds_cfg_preset_set_menu installFlake false
    nds_cfg_set INSTALL_KIND "flake"
    nds_cfg_set INSTALL_COMPOSER "toolkit"
    nds_cfg_set INSTALL_MODE "local"
}

action_preview() {
    nds_ui_h "Create or restore the toolkit ops VM"
    nds_ui_b ""
    nds_ui_b "You will configure restore vs create, the install flake URL, and disk / encryption."
    nds_ui_b ""
    nds_ui_b "After confirmation, NDS will:"
    nds_ui_i "generate (or restore) operator age + toolkit SSH into secret files"
    nds_ui_i "commit public keys + recipe to the leaf (never private keys)"
    nds_ui_i "Part A flake-installs locally, then copies secret files onto /mnt"
    nds_ui_b "Remote (nixos-anywhere) toolkit install is not supported yet."
    nds_ui_b ""
}

# Description: Keys, pubs, recipe. Does not install (Part A does).
nds_toolkit_compose() {
    local flake_root system host mode dest
    flake_root="${NDS_FLAKE_PROBE_DIR:-.}"
    system="$(basename "${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}")"
    host="$(nds_cfg_get FLAKE_HOST)"
    mode="$(nds_cfg_get CAST_TOOLKIT_MODE)"
    mode="${mode:-new}"

    [[ -n "$host" ]] || {
        error "Toolkit host name is empty"
        return 1
    }
    info "Generating toolkit keys and writing host files…"
    nds_cfg_set NETWORK_HOSTNAME "$host"
    export NDS_FLAKE_HOST="$host"

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

    dest="$(_nds_toolkit_secrets_dir)"
    nds_cfg_set TOOLKIT_AGE_KEY_FILE "${dest}/operator_age.txt"
    nds_cfg_set TOOLKIT_SSH_KEY_FILE "${dest}/toolkit_ssh"

    if [[ ! -d "${flake_root}/hosts/${system}/${host}" ]]; then
        error "Toolkit host ${host} is missing under hosts/${system}/ — add that host in the leaf first"
        return 1
    fi

    nds_flake_write_host_nds_env "$flake_root" "$host" || return 1
    nds_install_flake_run_hooks "$flake_root" post_scaffold || return 1

    nds_install_flake_commit_push_leaf "$flake_root" \
        "nds: toolkit ${mode} host ${host}" || return 1

    nds_install_flake_run_hooks "$flake_root" pre_install || return 1
    return 0
}

# Description: Toolkit cannot deliver operator keys over nixos-anywhere yet.
_nds_toolkit_refuse_remote() {
    local install_mode
    install_mode="$(nds_cfg_get INSTALL_MODE)"
    install_mode="${install_mode:-local}"
    if [[ "$install_mode" == "remote" ]]; then
        error "toolkit is local-only until operator keys can be delivered to a remote target (set INSTALL_MODE=local)"
        return 1
    fi
    return 0
}

action_setup() {
    nds_mode_resolve || true
    [[ -n "$(nds_cfg_get FLAKE_HOST)" ]] || nds_cfg_set FLAKE_HOST "control-toolkit"
    _nds_toolkit_refuse_remote || exit 11

    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
        if nds_mode_is_unattended; then
            error "FLAKE_REPO_URL is required"
            exit 11
        fi
        nds_cfg_ask_url FLAKE_REPO_URL "Install flake Git URL" "" true
    fi

    nds_install_open_leaf || exit 14
    nds_cfg_set NETWORK_HOSTNAME "$(nds_cfg_get FLAKE_HOST)"
    nds_flake_prepare remote

    if ! nds_sm_validate; then
        if nds_mode_is_unattended; then
            error "Unattended mode: configuration incomplete"
            exit 11
        fi
        nds_cfg_prompt_errors
        nds_sm_validate || exit 11
    fi
    nds_sm_menu || exit 12
    _nds_toolkit_refuse_remote || exit 11
    nds_install_confirm || exit 13

    nds_toolkit_compose || exit 15
    nds_cfg_set INSTALL_KIND "flake"
    nds_install_apply || exit $?

    nds_toolkit_install_keys_to_target /mnt || true
    nds_toolkit_ensure_cast_fetch_key /mnt || true
    nds_toolkit_seed_scripts_to_target /mnt || true
    nds_install_flake_run_hooks "${NDS_FLAKE_PROBE_DIR:-.}" post_install || exit 15
}
