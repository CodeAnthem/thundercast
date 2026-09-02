#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git auth wizard new-key and registration menus
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-07 | Modified: 2026-08-26
# ==================================================================================================

# Description: Ask gh CLI vs manual registration.
# Arguments:
# - choice: <Nameref> Receives gh or manual (required — do not use command substitution)
nds_git_wizard_ask_register_method() {
    local -n _choice=${1:?choice_nameref}
    local existing

    existing="${ nds_feat_cfg_get GIT_SSH_KEY_REGISTER_METHOD 2>/dev/null || true; }"
    if [[ -n "$existing" ]]; then
        [[ "$existing" == "gh" ]] && _choice=gh || _choice=manual
        return 0
    fi

    if git_gh_session_ready 2>/dev/null; then
        _choice=gh
        nds_feat_cfg_set GIT_SSH_KEY_REGISTER_METHOD gh
        return 0
    fi

    if ! git_gh_bin_ready 2>/dev/null; then
        nds_git_warm_gh 2>/dev/null || true
    fi
    if ! git_gh_bin_ready 2>/dev/null && ! command -v nix &>/dev/null; then
        _choice=manual
        return 0
    fi

    nds_aa_ask_numbered_choice GIT_SSH_KEY_REGISTER_METHOD \
        "gh|manual" \
        "gh=Use gh CLI|manual=Show the key and add it on GitHub yourself" \
        "gh"
    existing="${ nds_feat_cfg_get GIT_SSH_KEY_REGISTER_METHOD; }"
    [[ "$existing" == "gh" ]] && _choice=gh || _choice=manual
}

# Description: Register a deploy key for one repo (gh or manual).
# Arguments:
# - owner:     <String> Repository owner
# - repo:      <String> Repository name
# - host:      <String> Git host
# - read_only: <String> true (default) or false
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_deploy() {
    local owner="$1" repo="$2" host="${3:-github.com}" read_only="${4:-true}"
    local method="" pub register_url

    nds_git_wizard_ask_register_method method || return 1
    if [[ "$method" == "gh" ]]; then
        nds_git_wizard_menu_gh_deploy "$owner" "$repo" "$read_only" || return 1
        return 0
    fi

    nds_git_deploy_key_generate "$owner" "$repo" || return 1
    pub="${ nds_git_deploy_key_pubkey_path "$owner" "$repo"; }"
    register_url="${ nds_git_deploy_key_register_url "$host" "$owner" "$repo"; }"
    NDS_GIT_AUTH_REGISTER_URLS=("$register_url")
    nds_git_wizard_menu_manual_deploy "$owner" "$repo" "$host" "$read_only" || return 1
    return 0
}

# Description: Register account SSH key (gh or manual, machine-user warning).
# Arguments:
# - repos: <String...> owner/repo seeds for scope display
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_account() {
    local -a repos=("$@")
    local method=""

    nds_ui_b "Use a dedicated GitHub machine user — not your personal account."
    nds_ui_b ""

    nds_git_wizard_ask_register_method method || return 1
    if [[ "$method" == "gh" ]]; then
        # Download + login before keygen (see menu_gh_account).
        nds_git_wizard_menu_gh_account "${repos[@]}" || return 1
        return 0
    fi

    if [[ ! -f "${ nds_git_session_pubkey_path; }" ]]; then
        nds_git_key_generate "${ nds_git_session_key_path; }" || return 1
    fi
    nds_git_keys_register "${ nds_git_session_key_path; }" || true
    nds_git_auth_set_mode account

    nds_git_wizard_menu_manual_account || return 1
    return 0
}

# Description: Register deploy keys only for repositories still missing access.
# Arguments:
# - need: <String> read or write (this call)
# - urls: <String...> Failed git URLs
# Returns:
# - <Bool> 0 on success
nds_git_wizard_register_deploy_for_urls() {
    local need="$1"
    shift
    local url ssh_url parsed host owner repo read_only
    declare -A seen=()

    for url in "$@"; do
        ssh_url=${ _nds_git_url_toSsh "$url"; }
        parsed=${ _nds_git_url_parse "$ssh_url"; } || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        [[ -n "${seen[${owner}/${repo}]:-}" ]] && continue
        seen["${owner}/${repo}"]=1
        read_only="true"
        if declare -f nds_git_access_deploy_read_only &>/dev/null; then
            read_only="${ nds_git_access_deploy_read_only "$owner" "$repo" "$need"; }"
        fi
        nds_git_wizard_register_deploy "$owner" "$repo" "$host" "$read_only" || return 1
    done
    return 0
}
