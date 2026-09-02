#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access logic + feature entry (no TTY in logic_*)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-31
# Description:   Normalize/probe from config AA; entry may call prompts then verify
# ==================================================================================================

# Description: Read a git-access cfg key from the bound AA, store, or empty.
_nds_git_access_cfg_get() {
    local key="$1" val=""
    declare -f nds_feat_cfg_get &>/dev/null && val="${ nds_feat_cfg_get "$key" 2>/dev/null || true; }"
    [[ -z "$val" ]] && declare -f nds_cfg_get &>/dev/null && val="${ nds_cfg_get "$key" 2>/dev/null || true; }"
    printf '%s\n' "$val"
}

# Description: Normalize a per-call access need (read or write).
# Arguments:
# - need: <String> write|rw|push, or anything else for read
# Returns:
# - <String> write or read (stdout)
nds_git_access_normalize_need() {
    case "${1,,}" in
        write|rw|push) printf 'write\n' ;;
        *) printf 'read\n' ;;
    esac
}

# Description: True when owner/repo is the install flake (FLAKE_REPO_URL).
# Related flake inputs are not the write target.
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
nds_git_access_is_need_target() {
    local owner="$1" repo="$2"
    local lo lr url parsed leaf_owner leaf_repo
    if declare -f _nds_git_is_install_leaf &>/dev/null && _nds_git_is_install_leaf "$owner" "$repo"; then
        return 0
    fi
    lo="${ _nds_git_access_cfg_get GIT_ACCESS_OWNER; }"
    lr="${ _nds_git_access_cfg_get GIT_ACCESS_REPO; }"
    if [[ -n "$lo" && -n "$lr" && "${owner,,}" == "${lo,,}" && "${repo,,}" == "${lr,,}" ]]; then
        return 0
    fi
    url="${NDS_FLAKE_REPO_URL:-}"
    [[ -z "$url" ]] && url="${ _nds_git_access_cfg_get FLAKE_REPO_URL; }"
    [[ -n "$url" ]] || return 1
    declare -f _nds_git_url_toSsh &>/dev/null && declare -f _nds_git_url_parse &>/dev/null || return 1
    url="${ _nds_git_url_toSsh "$url"; }"
    parsed="${ _nds_git_url_parse "$url"; }" || return 1
    IFS=$'\t' read -r _ leaf_owner leaf_repo <<< "$parsed"
    [[ "${owner,,}" == "${leaf_owner,,}" && "${repo,,}" == "${leaf_repo,,}" ]]
}

# Description: GitHub deploy-key read_only flag for this call (write only on the need target).
# Arguments:
# - owner: <String> Repository owner
# - repo:  <String> Repository name
# - need:  <String> Per-call need (read or write)
# Returns:
# - <String> true or false (stdout)
nds_git_access_deploy_read_only() {
    local owner="$1" repo="$2" need="$3"
    if [[ "${ nds_git_access_normalize_need "$need"; }" == "write" ]] \
        && nds_git_access_is_need_target "$owner" "$repo"; then
        printf 'false\n'
    else
        printf 'true\n'
    fi
}

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

    if parsed=${ _nds_git_url_parse "$url"; }; then
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        if [[ "$url" != git@* && "$url" != ssh://* ]]; then
            ssh_url="${ _nds_git_url_formatSsh "$host" "$owner" "$repo"; }"
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

    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_bindFromStore "$url" 2>/dev/null || true

    if _nds_git_env_verifyQuiet "$url"; then
        success "Git access confirmed for ${owner}/${repo}."
        nds_git_access_mark_verified
        _g_try[GIT_ACCESS_VERIFIED]="true"
        return 0
    fi

    if declare -f nds_git_access_apply_map &>/dev/null && nds_git_access_apply_map "$url"; then
        nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
        if _nds_git_env_verifyQuiet "$url"; then
            success "Git access confirmed for ${owner}/${repo} (configured map)."
            nds_git_access_mark_verified
            _g_try[GIT_ACCESS_VERIFIED]="true"
            return 0
        fi
    fi

    if _nds_git_auth_try_existing_access "$url"; then
        nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
        if _nds_git_env_verifyQuiet "$url"; then
            success "Git access confirmed for ${owner}/${repo} (existing key)."
            if declare -f nds_git_access_set &>/dev/null; then
                nds_git_access_set method "$url" "import"
            fi
            _g_try[GIT_ACCESS_METHOD]="import"
            return 0
        fi
    fi
    return 1
}

# Description: Probe the flake URL via store and mark GIT_ACCESS_VERIFIED when OK.
nds_git_access_logic_verify() {
    local -n _g_ver=$1
    local url="${_g_ver[FLAKE_REPO_URL]:-}"
    local owner="${_g_ver[GIT_ACCESS_OWNER]:-}"
    local repo="${_g_ver[GIT_ACCESS_REPO]:-}"

    nds_git_keys_load_all || true
    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_bindFromStore "$url" 2>/dev/null || true
    if _nds_git_env_verifyQuiet "$url"; then
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

# Description: Feature entry — mode + config AA + per-call need/reason (mutates AA).
# UI uses nds_aa_ask_* / nds_feat_cfg_* while bound to this AA.
# Arguments:
# - mode:   <String> interactive|unattended
# - cfg:    <Nameref> Config AA (FLAKE_REPO_URL)
# - need:   <String|optional> read (default) or write
# - reason: <String|optional> Shown in the wizard (why this access is required)
nds_git_access_run() {
    local mode="${1:-interactive}"
    local -n _g_run=$2
    local need reason owner repo rc url need_bool
    local prev_aa="${NDS_CFG_AA_NAME:-}"

    need="${ nds_git_access_normalize_need "${3:-read}"; }"
    reason="${4:-}"
    need_bool=false
    [[ "$need" == "write" ]] && need_bool=true

    nds_git_access_logic_normalize _g_run || return 0
    owner="${_g_run[GIT_ACCESS_OWNER]:-}"
    repo="${_g_run[GIT_ACCESS_REPO]:-}"
    url="${_g_run[FLAKE_REPO_URL]:-}"
    export NDS_FLAKE_REPO_URL="$url"
    export NDS_FLAKE_SOURCE="${_g_run[FLAKE_SOURCE]:-remote}"

    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_bindFromStore "$url" 2>/dev/null || true
    git_store_needWrite "$url" "$need_bool" || return 1

    if declare -f nds_step_start_spin &>/dev/null; then
        nds_step_start_spin "Checking git access"
        if nds_git_access_logic_try _g_run; then
            if [[ "${_g_run[GIT_ACCESS_METHOD]:-}" == "import" ]]; then
                nds_step_complete "Git access confirmed for ${owner}/${repo} (existing key)"
            else
                nds_step_complete "Git access confirmed for ${owner}/${repo}"
            fi
            return 0
        fi
        nds_step_cancel
    elif nds_git_access_logic_try _g_run; then
        return 0
    fi

    case "${GIT_STORE_LAST_ERROR:-}" in
        unreachable)
            warn "Git host unreachable for ${owner}/${repo} (network / DNS)."
            ;;
        auth)
            debug "Git access needs authentication for ${owner}/${repo}."
            ;;
    esac

    if nds_mode_env_true "${NDS_GIT_AUTH_SKIP:-false}"; then
        case "${GIT_STORE_LAST_ERROR:-}" in
            unreachable)
                error "Cannot reach git host for ${owner}/${repo} (unset NDS_GIT_AUTH_SKIP does not help — fix network)"
                ;;
            *)
                if [[ "$need" == "write" ]]; then
                    error "Private repo ${owner}/${repo} needs write SSH access (unset NDS_GIT_AUTH_SKIP and configure a key)"
                else
                    error "Private repo ${owner}/${repo} needs SSH access (unset NDS_GIT_AUTH_SKIP and configure a key)"
                fi
                ;;
        esac
        return 1
    fi

    if [[ "$mode" == "unattended" ]] && ! nds_git_access_wants_gh_ui _g_run \
        && ! _nds_git_access_has_prompt_mode "${_g_run[FLAKE_REPO_URL]:-}"; then
        case "${GIT_STORE_LAST_ERROR:-}" in
            unreachable)
                error "Unattended git access failed for ${owner}/${repo} — host unreachable"
                ;;
            auth)
                error "Unattended git access failed for ${owner}/${repo} — auth required (keys / NDS_GIT_KEY_MODE / GH)"
                ;;
            *)
                error "Unattended git access failed for ${owner}/${repo} — provide keys, NDS_GIT_KEY_MODE, or set GIT method for GH UI"
                ;;
        esac
        return 1
    fi

    nds_cfg_aa_bind _g_run
    while true; do
        export NDS_FLAKE_REPO_URL="${_g_run[FLAKE_REPO_URL]:-}"
        export NDS_FLAKE_SOURCE="${_g_run[FLAKE_SOURCE]:-remote}"
        nds_git_auth_prompts _g_run "$need" "$reason"
        rc=$?
        [[ "$rc" -eq "${NDS_ACTION_BACK:-10}" ]] && continue
        [[ "$rc" -ne 0 ]] && continue

        url="${_g_run[FLAKE_REPO_URL]:-}"
        nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
        git_store_needWrite "$url" "$need_bool" || true

        if declare -f nds_step_start_spin &>/dev/null; then
            nds_step_start_spin "Verifying git access"
            if nds_git_access_logic_verify _g_run; then
                if declare -f nds_git_access_set &>/dev/null; then
                    nds_git_access_set method "${_g_run[FLAKE_REPO_URL]}" \
                        "${_g_run[GIT_ACCESS_METHOD]:-${_g_run[GIT_SSH_KEY_REGISTER_METHOD]:-import}}"
                fi
                nds_step_complete "Git access confirmed for ${owner}/${repo}"
                NDS_CFG_AA_NAME="$prev_aa"
                return 0
            fi
            nds_step_cancel
        elif nds_git_access_logic_verify _g_run; then
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
