#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git ↔ GitHub orchestration (uses tools nds_gh_*)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-05 | Modified: 2026-08-17
# Description:   Git owns key paths / titles; collision UI in git/keys/ui; GH API in tools/
# ==================================================================================================

# Description: Register deploy key via gh, prompting on title collision (rc 41).
nds_git_register_deploy_key() {
    local pub_file="$1" owner="$2" repo="$3" title="$4"
    local collision rc

    while true; do
        collision="${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}"
        nds_gh_register_deploy_key "$pub_file" "$owner" "$repo" "$title" "$collision"
        rc=$?
        if [[ "$rc" -eq "${NDS_GH_RC_TITLE_COLLISION:-41}" ]]; then
            nds_git_ui_ask_gh_title_collision \
                "Deploy key title \"${title}\" already exists on ${owner}/${repo} with a different public key." \
                || {
                    error "Deploy key registration cancelled for ${owner}/${repo} (title collision)."
                    return 1
                }
            continue
        fi
        return "$rc"
    done
}

# Description: Generate (if needed) deploy key path and register via gh API.
nds_git_register_deploy_for_repo() {
    local owner="$1" repo="$2"
    local pub title key_path

    key_path="$(nds_git_deploy_key_path "$owner" "$repo")"
    pub="${key_path}.pub"
    if [[ ! -f "$pub" ]]; then
        nds_git_deploy_key_generate "$owner" "$repo" || return 1
    else
        nds_git_keys_register "$key_path" || true
    fi
    title="$(nds_git_deploy_key_title "$owner" "$repo")"
    if declare -f _nds_git_is_install_leaf &>/dev/null && _nds_git_is_install_leaf "$owner" "$repo" \
        && [[ "${NDS_CURRENT_ACTION:-}" == "remoteAction" ]]; then
        NDS_GH_DEPLOY_READ_ONLY=false
        export NDS_GH_DEPLOY_READ_ONLY
    else
        NDS_GH_DEPLOY_READ_ONLY=true
        export NDS_GH_DEPLOY_READ_ONLY
    fi
    nds_git_register_deploy_key "$pub" "$owner" "$repo" "$title" || return 1
    unset NDS_GH_DEPLOY_READ_ONLY
    return 0
}

# Description: Register account SSH key via gh, prompting on title collision.
nds_git_register_account_key() {
    local pub_file="$1" title="$2"
    local collision rc

    while true; do
        collision="${NDS_GH_KEY_TITLE_COLLISION:-${NDS_GIT_SSH_KEY_TITLE_COLLISION:-}}"
        nds_gh_register_account_key "$pub_file" "$title" "$collision"
        rc=$?
        if [[ "$rc" -eq "${NDS_GH_RC_TITLE_COLLISION:-41}" ]]; then
            nds_git_ui_ask_gh_title_collision \
                "SSH key title \"${title}\" already exists on GitHub with a different public key" \
                || {
                    error "SSH key registration cancelled (title collision)."
                    return 1
                }
            continue
        fi
        return "$rc"
    done
}

# Description: Register account SSH key for GitHub repos in scope (expands flake.lock).
nds_git_register_for_repos() {
    local pub_file="$1"
    shift
    local -a repos=("$@")
    local key_title

    [[ -f "$pub_file" ]] || return 1
    [[ ${#repos[@]} -gt 0 ]] || return 1
    nds_gh_available || return 1

    key_title="$(nds_git_ssh_key_title)"
    nds_git_key_load "$(nds_git_session_key_path)" || true

    mapfile -t repos < <(nds_git_expand_github_repos "${repos[@]}")
    nds_install_log "git: registering account SSH key for ${#repos[@]} repo(s)"

    nds_git_register_account_key "$pub_file" "$key_title" || return 1
    export NDS_GIT_SSH_KEY_READONLY=true
    return 0
}

# Description: Parse git URLs into owner/repo pairs for GitHub only.
nds_git_urls_to_github_repos() {
    local url parsed host owner repo
    for url in "$@"; do
        url=$(_nds_git_url_toSsh "$url")
        parsed=$(_nds_git_url_parse "$url") || continue
        IFS=$'\t' read -r host owner repo <<< "$parsed"
        nds_git_host_is_github "$host" || continue
        printf '%s/%s\n' "$owner" "$repo"
    done | sort -u
}

# Description: Fetch flake.lock git URLs from GitHub via gh API.
_nds_git_lock_git_urls() {
    local gh_repo="$1"
    local owner repo tmp

    owner="${gh_repo%%/*}"
    repo="${gh_repo##*/}"
    [[ -n "$owner" && -n "$repo" ]] || return 0

    tmp="$(mktemp)"
    if ! nds_gh_repo_file_content "$owner" "$repo" "flake.lock" >"$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi
    _nds_git_flake_lock_ssh_urls "$tmp"
    rm -f "$tmp"
}

# Description: Merge root repo(s) with GitHub repos referenced in their flake.lock.
nds_git_expand_github_repos() {
    local -a seeds=("$@")
    local -a out=()
    local -a gh_repos=()
    local gh_repo url

    out=("${seeds[@]}")
    for gh_repo in "${seeds[@]}"; do
        [[ -n "$gh_repo" ]] || continue
        mapfile -t gh_repos < <(nds_git_urls_to_github_repos "git@github.com:${gh_repo}.git")
        mapfile -t out < <(printf '%s\n' "${out[@]}" "${gh_repos[@]}")
        while IFS= read -r url; do
            [[ -n "$url" ]] || continue
            mapfile -t gh_repos < <(nds_git_urls_to_github_repos "$url")
            mapfile -t out < <(printf '%s\n' "${out[@]}" "${gh_repos[@]}")
        done < <(_nds_git_lock_git_urls "$gh_repo")
    done
    printf '%s\n' "${out[@]}" | awk 'NF' | sort -u
}
