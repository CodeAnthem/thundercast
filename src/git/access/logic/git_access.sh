#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access logic + feature entry (no TTY in logic_*)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-15
# Description:   Normalize/probe from config AA; entry may call prompts then verify
# ==================================================================================================

# Description: Normalize repo URL into cfg AA (SSH form when parseable).
nds_git_access_logic_normalize() {
    local -n _g_cfg=$1
    local url parsed host owner repo ssh_url

    url="${_g_cfg[FLAKE_REPO_URL]:-}"
    [[ -n "$url" ]] || return 1
    case "$url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 1 ;;
    esac

    if parsed=$(_nds_git_url_parse "$url"); then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            ssh_url="$(_nds_git_url_formatSsh "$host" "$owner" "$repo")"
            _g_cfg[FLAKE_REPO_URL]="$ssh_url"
            _g_cfg[FLAKE_LOCATION]="$ssh_url"
            _g_cfg[FLAKE_LOCAL_PATH]=""
            _g_cfg[FLAKE_SOURCE]="remote"
            url="$ssh_url"
        fi
        _g_cfg[GIT_ACCESS_HOST]="$host"
        _g_cfg[GIT_ACCESS_OWNER]="$owner"
        _g_cfg[GIT_ACCESS_REPO]="$repo"
    fi
    return 0
}

# Description: Try public / map / existing keys (no prompts).
nds_git_access_logic_try() {
    local -n _g_try=$1
    local url="${_g_try[FLAKE_REPO_URL]:-}"
    local owner="${_g_try[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_try[GIT_ACCESS_REPO]:-}"

    [[ -n "$url" ]] || return 1

    if nds_git_probe_public "$url" 2>/dev/null; then
        success "Public repository ${owner}/${repo} — no SSH key required."
        nds_install_log "git: public repo ${owner}/${repo}"
        nds_git_access_mark_verified
        _g_try[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi

    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        success "Git access confirmed for ${owner}/${repo} (configured map)."
        nds_git_access_mark_verified
        _g_try[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi

    if _nds_git_auth_try_existing_access "$url"; then
        success "Git access confirmed for ${owner}/${repo} (existing key)."
        nds_git_access_mark_verified
        if declare -f nds_git_access_set &>/dev/null; then
            nds_git_access_set method "$url" "import"
        fi
        _g_try[GIT_ACCESS_VERIFIED]="true"
        _g_try[GIT_ACCESS_METHOD]="import"
        return 0
    fi
    return 1
}

# Description: Probe the flake URL and mark GIT_ACCESS_VERIFIED when SSH works.
nds_git_access_logic_verify() {
    local -n _g_ver=$1
    local url="${_g_ver[FLAKE_REPO_URL]:-}"
    local owner="${_g_ver[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_ver[GIT_ACCESS_REPO]:-}"

    nds_git_keys_load_all || true
    if nds_git_probe_access "$url"; then
        success "Git access confirmed for ${owner}/${repo}."
        nds_git_access_mark_verified
        _g_ver[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi
    return 1
}

# Description: True when the chosen register method should show the gh CLI UI.
nds_git_access_wants_gh_ui() {
    local -n _g_gh=$1
    local method="${_g_gh[GIT_SSH_KEY_REGISTER_METHOD]:-${_g_gh[GIT_SSH_KEY_TYPE]:-}}"
    local kind="${_g_gh[GIT_AUTH_MODE]:-}"
    [[ "${method,,}" == *gh* || "${method,,}" == "account" \
        || "${kind,,}" == "gh" || "${kind,,}" == "account" ]]
}

# Description: Feature entry — mode + config AA (mutates AA).
# UI uses nds_aa_ask_* / nds_feat_cfg_* while bound to this AA.
nds_git_access_run() {
    local mode="${1:-interactive}"
    local -n _g_run=$2
    local owner repo rc
    local prev_aa="${NDS_CFG_AA_NAME:-}"

    nds_git_access_logic_normalize _g_run || return 0
    owner="${_g_run[GIT_ACCESS_OWNER]:-}"
    repo="${_g_run[GIT_ACCESS_REPO]:-}"
    export NDS_FLAKE_REPO_URL="${_g_run[FLAKE_REPO_URL]:-}"
    export NDS_FLAKE_SOURCE="${_g_run[FLAKE_SOURCE]:-remote}"

    if nds_git_access_logic_try _g_run; then
        return 0
    fi

    if nds_mode_env_true "${NDS_GIT_AUTH_SKIP:-false}"; then
        error "Private repo ${owner}/${repo} needs SSH access (unset NDS_GIT_AUTH_SKIP and configure a key)"
        return 1
    fi

    if [[ "$mode" == "unattended" ]] && ! nds_git_access_wants_gh_ui _g_run \
        && ! _nds_git_access_has_prompt_mode "${_g_run[FLAKE_REPO_URL]:-}"; then
        error "Unattended git access failed for ${owner}/${repo} — provide keys, NDS_GIT_KEY_MODE, or set GIT method for GH UI"
        return 1
    fi

    nds_cfg_aa_bind _g_run
    while true; do
        export NDS_FLAKE_REPO_URL="${_g_run[FLAKE_REPO_URL]:-}"
        export NDS_FLAKE_SOURCE="${_g_run[FLAKE_SOURCE]:-remote}"
        nds_git_auth_prompts _g_run
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue

        if nds_git_access_logic_verify _g_run; then
            if declare -f nds_git_access_set &>/dev/null; then
                nds_git_access_set method "${_g_run[FLAKE_REPO_URL]}" \
                    "${_g_run[GIT_ACCESS_METHOD]:-${_g_run[GIT_SSH_KEY_REGISTER_METHOD]:-import}}"
            fi
            NDS_CFG_AA_NAME="$prev_aa"
            return 0
        fi
        warn "Still no access — register a key on ${owner}/${repo} or import a working key."
        if nds_git_host_is_github "${_g_run[GIT_ACCESS_HOST]:-}" 2>/dev/null; then
            nds_git_ui_deploy_key_hint "$owner" "$repo"
        fi
        if [[ "$mode" == "unattended" ]] && ! nds_git_access_wants_gh_ui _g_run \
            && ! _nds_git_access_has_prompt_mode "${_g_run[FLAKE_REPO_URL]:-}"; then
            NDS_CFG_AA_NAME="$prev_aa"
            return 1
        fi
    done
}
