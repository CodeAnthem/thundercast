#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH auth gate + exit cleanup
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-31
# Description:   Exit cleanup + flake-input closure access gate
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_GIT_GH_CLEAR_SKIP

# Description: Clear gh session leftovers and flake-closure URL cache after success.
nds_git_access_cleanup_success() {
    git_gh_session_cleanup 2>/dev/null || true
    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true
}

# Description: EXIT hook — clear leftover gh session after install or abort.
nds_git_access_onExit() {
    local exit_code="${1:-$?}"
    local logged_in=false

    unset NDS_GIT_CLOSURE_URLS 2>/dev/null || true

    if [[ "${NDS_GIT_GH_LEFTOVER:-}" == "true" || "${NDS_GIT_GH_SESSION_ACTIVE:-}" == "true" ]]; then
        logged_in=true
    fi
    if declare -f git_gh_host_logged_in &>/dev/null; then
        git_gh_host_logged_in && logged_in=true
    elif declare -f git_gh_hosts_yml_has_github &>/dev/null; then
        git_gh_hosts_yml_has_github && logged_in=true
    fi

    if [[ "$logged_in" != "true" ]]; then
        nds_install_log "git: exit cleanup — no gh session to clear"
        return 0
    fi

    if [[ "${NDS_GIT_INSTALL_SUCCEEDED:-}" == "true" ]]; then
        git_gh_session_cleanup 2>/dev/null || true
        if declare -f git_gh_host_logged_in &>/dev/null && git_gh_host_logged_in; then
            nds_git_ui_offer_clear_gh_session && git_gh_session_cleanup || true
        fi
        return 0
    fi

    if nds_skip_menu NDS_GIT_GH_CLEAR_SKIP 2>/dev/null; then
        git_gh_session_cleanup 2>/dev/null || true
        return 0
    fi

    nds_git_ui_offer_clear_gh_session && git_gh_session_cleanup || true
    return 0
}

# Description: Record how this URL was accessed so restore recipes list every closure repo.
_nds_git_record_url_access() {
    local url="$1"
    local method path kind
    declare -f nds_git_access_set &>/dev/null || return 0
    method="$(nds_git_access_get method "$url" 2>/dev/null || true)"
    if [[ -z "$method" ]]; then
        method="$(nds_cfg_get GIT_ACCESS_METHOD 2>/dev/null || true)"
        [[ -z "$method" ]] && method="$(nds_cfg_get GIT_SSH_KEY_REGISTER_METHOD 2>/dev/null || true)"
        [[ -z "$method" ]] && method="$(nds_cfg_get GIT_AUTH_MODE 2>/dev/null || true)"
        method="${method:-import}"
        nds_git_access_set method "$url" "$method"
    fi
    path="$(nds_git_access_get key_path "$url" 2>/dev/null || true)"
    if [[ -z "$path" || ! -f "$path" ]] && declare -f _nds_git_identity_for_url &>/dev/null; then
        path="$(_nds_git_identity_for_url "$url" 2>/dev/null || true)"
    fi
    if [[ -z "$path" || ! -f "$path" ]]; then
        path="$(nds_git_session_key_path 2>/dev/null || true)"
    fi
    if [[ -n "$path" && -f "$path" ]]; then
        nds_git_access_set key_path "$url" "$path"
    fi
    kind="$(nds_cfg_get GIT_SSH_KEY_TYPE 2>/dev/null || true)"
    [[ -z "$kind" ]] && kind="$(nds_cfg_get GIT_AUTH_MODE 2>/dev/null || true)"
    if [[ -n "$kind" ]] && declare -f nds_git_access_set &>/dev/null; then
        nds_git_access_set key_kind "$url" "$kind"
    fi
}

_nds_git_closure_probe_one() {
    local url="$1" key dest="" parsed host owner repo

    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_bindFromStore "$url" 2>/dev/null || true
    git_store_needWrite "$url" false || return 1
    if _nds_git_env_verifyQuiet "$url"; then
        return 0
    fi

    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
        _nds_git_env_verifyQuiet "$url" && return 0
    fi
    if parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$url")" 2>/dev/null); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        dest="$(nds_git_deploy_key_path "$owner" "$repo" 2>/dev/null || true)"
        if [[ -n "$dest" && -f "$dest" ]] \
            && nds_git_probe_access_with_key "$url" "$dest"; then
            nds_git_keys_register "$dest" || true
            if declare -f nds_git_bind_key_to_url &>/dev/null; then
                nds_git_bind_key_to_url "$dest" "$url" || true
            fi
            nds_git_env_setKeyPath "$url" "$dest" 2>/dev/null || true
            return 0
        fi
    fi
    if declare -f nds_git_keys_list &>/dev/null; then
        while IFS= read -r key; do
            [[ -f "$key" ]] || continue
            if nds_git_probe_access_with_key "$url" "$key"; then
                if declare -f nds_git_bind_key_to_url &>/dev/null; then
                    nds_git_bind_key_to_url "$key" "$url" || true
                fi
                nds_git_env_setKeyPath "$url" "$key" 2>/dev/null || true
                return 0
            fi
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi
    return 1
}

_nds_git_closure_repo_label() {
    local url="$1" ssh_url parsed host owner repo
    ssh_url=$(_nds_git_url_toSsh "$url")
    if parsed=$(_nds_git_url_parse "$ssh_url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        printf '%s/%s' "$owner" "$repo"
        return 0
    fi
    printf '%s' "$ssh_url"
}

_nds_git_closure_url_owner() {
    local url="$1" parsed host owner repo
    parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$url")") || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    printf '%s' "$owner"
}

# Description: True when the user is importing an existing private key (paste/path).
_nds_git_auth_uses_existing_key() {
    local source route existing
    existing="$(nds_cfg_get GIT_EXISTING_KEY 2>/dev/null || true)"
    source="$(nds_cfg_get GIT_KEY_SOURCE 2>/dev/null || true)"
    route="$(nds_cfg_get GIT_AUTH_ROUTE 2>/dev/null || true)"
    [[ "$existing" == "true" || "$source" == "have" \
        || "$route" == "paste" || "$route" == "path" || "$route" == "import" ]]
}

# Description: When strategy is *-all, register remaining same-owner keys before probing.
# Avoids a FAIL screen for flake.lock siblings that deploy-all already promised to cover.
# Existing-key (paste/path) imports per remaining repo instead of generating new keys.
_nds_git_closure_preapply_strategy() {
    local root_url="${1:-}"
    shift
    local -a urls=("$@") pending=()
    local strategy url owner root_owner=""

    [[ ${#urls[@]} -gt 0 ]] || return 0
    strategy="$(nds_cfg_get GIT_ACCESS_STRATEGY 2>/dev/null || true)"
    [[ "$strategy" == "deploy-all" || "$strategy" == "account-all" ]] || return 0

    if [[ -n "$root_url" ]]; then
        root_owner="$(_nds_git_closure_url_owner "$root_url")" || root_owner=""
    fi
    if [[ -z "$root_owner" ]]; then
        root_owner="$(_nds_git_closure_url_owner "${urls[0]}")" || root_owner=""
    fi

    for url in "${urls[@]}"; do
        _nds_git_closure_probe_one "$url" &>/dev/null && continue
        owner="$(_nds_git_closure_url_owner "$url")" || owner=""
        if [[ -n "$root_owner" && "$owner" == "$root_owner" ]]; then
            pending+=("$url")
        fi
    done
    [[ ${#pending[@]} -gt 0 ]] || return 0

    case "$strategy" in
        deploy-all)
            if _nds_git_auth_uses_existing_key; then
                info "Need private keys for ${#pending[@]} related repositories..."
                if declare -f nds_git_wizard_import_each_url &>/dev/null; then
                    nds_git_wizard_import_each_url "${pending[@]}" || return 1
                fi
            else
                info "Creating deploy keys for ${#pending[@]} related repositories..."
                if declare -f nds_git_wizard_register_deploy_for_urls &>/dev/null; then
                    nds_git_wizard_register_deploy_for_urls "read" "${pending[@]}" || return 1
                fi
            fi
            nds_git_keys_load_all || true
            nds_git_ssh_config_refresh || true
            ;;
        account-all)
            return 0
            ;;
    esac
    return 0
}

# Description: Probe SSH access for every flake input URL before install proceeds.
nds_git_ensure_flake_closure_access() {
    local flake_root="${1:-}" root_url="${2:-}"
    local -a urls=() failed=()
    local url ssh_url rc allow
    local mode="${NDS_MODE:-interactive}"

    nds_mode_resolve || true
    mode="${NDS_MODE:-interactive}"

    nds_git_keys_load_all || true

    if [[ -n "$flake_root" && -d "$flake_root" ]]; then
        mapfile -t urls < <(_nds_git_flake_collect_git_remote_urls "$flake_root" "$root_url")
    elif [[ -n "$root_url" ]]; then
        if [[ ! -f "${NDS_FLAKE_PROBE_REPO:-}/flake.nix" ]]; then
            if declare -f nds_step_exec &>/dev/null; then
                nds_step_exec "Cloning flake repository" \
                    nds_git_clone_flake_probe "$root_url" || true
            else
                info "Cloning flake repository..."
                nds_git_clone_flake_probe "$root_url" || true
            fi
        fi
        mapfile -t urls < <(_nds_git_flake_collect_git_remote_urls_from_root "$root_url")
    else
        error "Flake root or repo URL required for closure check"
        return 1
    fi

    [[ ${#urls[@]} -gt 0 ]] || return 0

    NDS_GIT_CLOSURE_URLS="$(printf '%s\n' "${urls[@]}")"

    _nds_git_closure_preapply_strategy "$root_url" "${urls[@]}" || true
    nds_git_keys_load_all || true

    while true; do
        if declare -f nds_step_start_spin &>/dev/null \
            && [[ -z "${NDS_UI_STEP_SPIN_PID:-}" ]]; then
            nds_step_start_spin "Verifying git input access"
        fi

        failed=()
        for url in "${urls[@]}"; do
            nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
            nds_git_env_bindFromStore "$url" 2>/dev/null || true
            git_store_needWrite "$url" false || true

            if _nds_git_env_verifyQuiet "$url" \
                || _nds_git_closure_probe_one "$url" &>/dev/null; then
                debug "Git access OK: $url"
                _nds_git_record_url_access "$url"
                nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
            else
                failed+=("$url")
            fi
        done

        if [[ ${#failed[@]} -eq 0 ]]; then
            if declare -f nds_step_complete &>/dev/null && [[ -n "${NDS_UI_STEP_NAME:-}" ]]; then
                nds_step_complete "Git input access OK"
            else
                success "Access granted: ${#urls[@]} repositories"
            fi
            nds_install_log "git: closure access OK (${#urls[@]} repos)"
            nds_git_access_mark_verified
            return 0
        fi

        for url in "${failed[@]}"; do
            ssh_url=$(_nds_git_url_toSsh "$url")
            nds_install_log "git: no access — ${ssh_url}"
        done

        if nds_mode_env_true "${NDS_GIT_AUTH_SKIP:-false}"; then
            if declare -f nds_step_fail &>/dev/null && [[ -n "${NDS_UI_STEP_NAME:-}" ]]; then
                nds_step_fail "Git input access"
            fi
            error "Cannot verify SSH access to all flake git inputs (NDS_GIT_AUTH_SKIP set - unset it and configure keys)"
            return 1
        fi

        if [[ "$mode" == "unattended" ]]; then
            allow=false
            local -A _gh_cfg=()
            nds_cfg_aa_from_store _gh_cfg 2>/dev/null || true
            if nds_git_access_wants_gh_ui _gh_cfg; then
                allow=true
            fi
            for url in "${failed[@]}"; do
                if declare -f _nds_git_access_has_prompt_mode &>/dev/null \
                    && _nds_git_access_has_prompt_mode "$url"; then
                    allow=true
                    break
                fi
            done
            if [[ "$allow" != "true" ]]; then
                if declare -f nds_step_fail &>/dev/null && [[ -n "${NDS_UI_STEP_NAME:-}" ]]; then
                    nds_step_fail "Git input access"
                fi
                error "Unattended: missing SSH access to flake inputs — configure keys, NDS_GIT_KEY_MODE, or allow GH auth UI"
                return 1
            fi
        fi

        if declare -f nds_step_cancel &>/dev/null; then
            nds_step_cancel
        fi
        nds_git_auth_wizard_step_closure "${failed[@]}"
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue
        nds_git_keys_load_all || true
        nds_git_ssh_config_refresh || true
        for url in "${urls[@]}"; do
            nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
        done
        _nds_git_closure_preapply_strategy "$root_url" "${urls[@]}" || true
    done
}

# Description: Try import path, env key body, session keys, and discovered ~/.ssh keys.
# Arguments:
# - url: <String> Git URL to probe
# Returns:
# - <Bool> 0 when access works with an existing key
_nds_git_auth_try_existing_access() {
    local url="$1"
    local found

    nds_git_auth_try_import_path && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    nds_git_auth_try_import_body && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    if declare -f nds_git_register_keys_in_dir &>/dev/null; then
        nds_git_register_keys_in_dir "$PWD"
        nds_git_register_keys_in_dir "/root/.ssh"
        if [[ -n "${NDS_GIT_IMPORT_KEY_PATH:-}" ]]; then
            if [[ -d "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
                nds_git_register_keys_in_dir "${NDS_GIT_IMPORT_KEY_PATH}"
            elif [[ -f "${NDS_GIT_IMPORT_KEY_PATH}" ]]; then
                nds_git_register_keys_in_dir "$(dirname "${NDS_GIT_IMPORT_KEY_PATH}")"
            fi
        fi
    fi
    if nds_git_probe_access "$url"; then
        nds_git_auth_set_mode imported
        return 0
    fi

    nds_git_auth_try_session_key && nds_git_keys_register "$(nds_git_session_key_path)" 2>/dev/null || true
    nds_git_keys_load_all || true
    if nds_git_probe_access "$url"; then
        return 0
    fi

    if found="$(nds_git_discover_try_candidates "$url")"; then
        nds_git_auth_set_mode imported
        debug "Git access via discovered key: ${found}"
        return 0
    fi
    return 1
}
