#!/usr/bin/env bash
# ==================================================================================================
# NDS - Part A: apply a complete settings session (classic or flake, local or remote)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-08-28
# Description:   Disk/install only. Composers (Part B) must validate, then call this.
# ==================================================================================================

# Description: Clone the install flake with write access and set NDS_FLAKE_PROBE_DIR.
# Used by addRole, toolkit, and user remote actions. Not used by installFlake (read-only).
nds_install_open_leaf() {
    local host_dir probe_dir injected=0 parsed host owner repo key_path

    if [[ -z "$(nds_cfg_get FLAKE_REPO_URL)" ]]; then
        error "FLAKE_REPO_URL is required (install flake Git URL)"
        return 1
    fi

    nds_flake_prepare remote
    nds_app_actionHandler_logic_callFeature nds_git_access_run \
        "FLAKE_REPO_URL=$(nds_cfg_get FLAKE_REPO_URL)" \
        write \
        "This action git-pushes host files to the install flake." || return 1

    host_dir="${NDS_FLAKE_HOST_DIR:-hosts/x86_64-linux}"

    nds_step_start_spin "Cloning install flake"
    if ! probe_dir=$(nds_preflight_probe_flake "$(nds_cfg_get FLAKE_REPO_URL)"); then
        nds_step_fail "Install flake clone"
        return 1
    fi
    nds_step_complete "Install flake cloned"
    export NDS_FLAKE_PROBE_DIR="$probe_dir"

    nds_preset_inject_from_flake "$probe_dir" || true
    injected=$NDS_PRESET_INJECT_COUNT
    if [[ "${injected:-0}" -gt 0 ]]; then
        info "Loaded ${injected} custom preset(s) from flake .nds/"
    fi

    nds_preflight_apply_disko_strategy "$probe_dir" "${NDS_FLAKE_HOST}" "$host_dir"

    nds_step_start_spin "Verifying leaf write access"
    if nds_install_flake_probe_leaf_write "$probe_dir"; then
        nds_step_complete "Leaf write access OK"
    else
        nds_step_cancel
        warn "This key cloned the leaf but cannot push (GitHub deploy keys are read-only unless Allow write access is on)."
        parsed="$(_nds_git_url_parse "$(_nds_git_url_toSsh "$(nds_cfg_get FLAKE_REPO_URL)")" 2>/dev/null || true)"
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
            error "Cannot parse FLAKE_REPO_URL for write-key wizard"
            return 1
        fi
        while true; do
            nds_git_auth_wizard_step_repo "$host" "$owner" "$repo" write \
                "Need a key that can push host files to this repository." || return $?
            nds_step_start_spin "Verifying leaf write access"
            if nds_install_flake_probe_leaf_write "$probe_dir"; then
                nds_step_complete "Leaf write access OK"
                break
            fi
            nds_step_cancel
            warn "Still cannot push — generate a write deploy key or paste an account key."
        done
    fi

    if declare -f nds_git_register_keys_in_dir &>/dev/null; then
        nds_git_register_keys_in_dir "/root/.ssh"
        nds_git_register_keys_in_dir "$PWD"
        while IFS= read -r key_path; do
            [[ -n "$key_path" && -f "$key_path" ]] || continue
            nds_git_register_keys_in_dir "$(dirname "$key_path")"
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi

    nds_git_ensure_flake_closure_access "$probe_dir" "$(nds_cfg_get FLAKE_REPO_URL)" || return 1

    export NDS_FLAKE_PREPARED=1
    return 0
}

# Description: Infer INSTALL_KIND from the session when the composer omitted it.
_nds_install_apply_kind() {
    local kind
    kind="$(nds_cfg_get INSTALL_KIND)"
    if [[ -n "$kind" ]]; then
        printf '%s\n' "$kind"
        return 0
    fi
    if [[ -n "$(nds_cfg_get FLAKE_HOST)" \
        || -n "$(nds_cfg_get FLAKE_REPO_URL)" \
        || -n "$(nds_cfg_get FLAKE_LOCAL_PATH)" ]]; then
        printf 'flake\n'
        return 0
    fi
    printf 'classic\n'
}

# Description: Disk/remote wipe confirm. Composers that git-push (addRole, toolkit,
#              remoteAction) must call this after the settings menu and before compose.
#              Sets NDS_INSTALL_CONFIRMED=1 so Part A does not ask again.
nds_install_confirm() {
    local kind disk_strategy disk_target
    [[ "${NDS_INSTALL_CONFIRMED:-}" == "1" ]] && return 0
    kind="$(_nds_install_apply_kind)"
    case "$kind" in
        classic)
            disk_strategy="$(nds_cfg_get DISK_STRATEGY)"
            disk_strategy="${disk_strategy:-nds}"
            disk_target="$(nds_cfg_get DISK_TARGET)"
            nds_preflight_install "$disk_target" || return 1
            nds_install_ui_confirm_install "$disk_target" "$disk_strategy" || return 1
            ;;
        flake)
            if [[ "${NDS_FLAKE_PREPARED:-}" != "1" ]]; then
                nds_flake_install_prepare_and_verify || return 1
            fi
            nds_flake_install_confirm || return 1
            ;;
        *)
            error "Unknown INSTALL_KIND=${kind} (classic|flake)"
            return 1
            ;;
    esac
    export NDS_INSTALL_CONFIRMED=1
    return 0
}

# Description: Classic Part A (partition, nixcfg, nixos-install, finish).
nds_install_apply_classic() {
    local disk_strategy disk_target
    disk_strategy="$(nds_cfg_get DISK_STRATEGY)"
    disk_strategy="${disk_strategy:-nds}"
    disk_target="$(nds_cfg_get DISK_TARGET)"

    nds_preflight_install "$disk_target" || return 11
    if [[ "${NDS_INSTALL_CONFIRMED:-}" != "1" ]]; then
        nds_install_ui_confirm_install "$disk_target" "$disk_strategy" || return 13
        export NDS_INSTALL_CONFIRMED=1
    fi

    nds_install_ui_section_nixos_install
    nds_install_log "apply: classic starting"

    NDS_UI_QUIET=true
    nds_step_exec "Generating access secrets" _nds_install_generate_access_secrets || return 14
    nds_step_exec "Generating configuration.nix" nds_nixcfg_write_classic || return 14

    nds_nixos_install || return 15
    nds_install_finish || return 16
}

# Description: Flake Part A (prepare if needed, confirm, nixos-install --flake, finish).
nds_install_apply_flake() {
    local install_mode
    install_mode="$(nds_cfg_get INSTALL_MODE)"
    install_mode="${install_mode:-local}"

    if [[ "${NDS_FLAKE_PREPARED:-}" != "1" ]]; then
        nds_flake_install_prepare_and_verify || return 11
    fi
    if [[ "${NDS_INSTALL_CONFIRMED:-}" != "1" ]]; then
        nds_flake_install_confirm || return 13
        export NDS_INSTALL_CONFIRMED=1
    fi

    nds_install_ui_section_nixos_install
    nds_install_log "apply: flake starting (mode=${install_mode})"
    nds_nixos_install_flake || return 15
    export NDS_GIT_INSTALL_SUCCEEDED=true
    nds_git_access_cleanup_success

    if [[ "$install_mode" == "remote" ]]; then
        nds_install_remote_finish || return 16
    else
        nds_install_finish || return 16
    fi
}

# Description: Apply the live settings session. Call nds_sm_validate first (Part B).
# Returns:
# - <Int> 0 on success; action-style codes 11–16 on failure
nds_install_apply() {
    local kind
    nds_mode_resolve || true
    if declare -f nds_sm_materialize_secrets &>/dev/null; then
        nds_sm_materialize_secrets || return 11
    fi
    if ! nds_sm_validate; then
        error "Apply: configuration incomplete or invalid"
        return 11
    fi
    kind="$(_nds_install_apply_kind)"
    nds_cfg_set INSTALL_KIND "$kind"
    case "$kind" in
        classic) nds_install_apply_classic ;;
        flake) nds_install_apply_flake ;;
        *)
            error "Unknown INSTALL_KIND=${kind} (classic|flake)"
            return 11
            ;;
    esac
}
