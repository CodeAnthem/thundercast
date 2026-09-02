#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git store env bridge (GIT_REPO_* ↔ NDS keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-09-02
# Description:   Maintain ${GIT_ENV_PREFIX}_<safeUrl>_keyPath|targetDir for the git utility store
#                (default prefix GIT_REPO via git_store_setEnvPrefix / GIT_ENV_PREFIX).
# ==================================================================================================

# Description: Export GIT_REPO_<safe>_keyPath and write store keyPath.
# Arguments:
# - url:     <String> Git remote URL
# - keyPath: <String> Private key path
# Returns:
# - <Bool> 0 when indexed and set
nds_git_env_setKeyPath() {
    local url="${1:-}" keyPath="${2:-}"
    [[ -n "$url" && -n "$keyPath" ]] || return 1
    declare -f git_store_exportField &>/dev/null || return 1
    git_store_index "$url" || return 1
    git_store_set "$url" keyPath "$keyPath"
    git_store_exportField "$url" keyPath
}

# Description: Export GIT_REPO_<safe>_targetDir and write store targetDir.
# Arguments:
# - url: <String> Git remote URL
# - dir: <String> Clone / worktree directory
# Returns:
# - <Bool> 0 when indexed and set
nds_git_env_setTargetDir() {
    local url="${1:-}" dir="${2:-}"
    [[ -n "$url" && -n "$dir" ]] || return 1
    declare -f git_store_exportField &>/dev/null || return 1
    git_store_index "$url" || return 1
    git_store_set "$url" targetDir "$dir"
    git_store_exportField "$url" targetDir
}

# Description: If store already has a real keyPath file, export overlay env for it.
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <Bool> 0 when exported
nds_git_env_bindFromStore() {
    local url="${1:-}"
    [[ -n "$url" ]] || return 1
    declare -f git_store_hasKey &>/dev/null || return 1
    declare -f git_store_exportField &>/dev/null || return 1
    git_store_hasKey "$url" || return 1
    git_store_exportField "$url" keyPath
}

# Description: Sync NDS session / identity key for a URL into GIT_REPO_* + store.
# Prefers NDS_GIT_KEY_PATH map, then _nds_git_identity_for_url.
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <Bool> 0 when a key was bound
nds_git_env_syncKeyFromNds() {
    local url="${1:-}" keyPath="" norm=""
    [[ -n "$url" ]] || return 1

    if declare -p NDS_GIT_KEY_PATH &>/dev/null; then
        if declare -f git_url_toSsh &>/dev/null; then
            norm=${ git_url_toSsh "$url"; } || norm="$url"
        else
            norm="$url"
        fi
        keyPath="${NDS_GIT_KEY_PATH[$norm]:-}"
        [[ -z "$keyPath" || ! -f "$keyPath" ]] && keyPath="${NDS_GIT_KEY_PATH[$url]:-}"
    fi
    if [[ -z "$keyPath" || ! -f "$keyPath" ]] \
        && declare -f _nds_git_identity_for_url &>/dev/null; then
        keyPath=${ _nds_git_identity_for_url "$url" 2>/dev/null || true; }
    fi
    [[ -n "$keyPath" && -f "$keyPath" ]] || return 1
    nds_git_env_setKeyPath "$url" "$keyPath"
}

# Description: Store verifyAccess with GIT_INTERACTIVE=0 (NDS owns wizard prompts).
# Arguments:
# - url:    <String> Git remote URL
# - reason: <String|optional>
# Returns:
# - <Bool> 0 when access is satisfied
_nds_git_env_verifyQuiet() {
    local url="${1:-}" reason="${2:-}"
    local prev="${GIT_INTERACTIVE-}" rc
    export GIT_INTERACTIVE=0
    git_store_verifyAccess "$url" "$reason"
    rc=$?
    if [[ -n "${prev}" ]]; then
        export GIT_INTERACTIVE="$prev"
    else
        unset GIT_INTERACTIVE
    fi
    return "$rc"
}

# Description: True when a remote answers ls-remote with no SSH identity (public).
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when anonymously reachable
nds_git_env_isPublic() {
    local url="${1:-}" ssh_url
    local -a envv=(
        "GIT_TERMINAL_PROMPT=0"
        "GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o IdentitiesOnly=yes"
    )

    [[ -n "$url" ]] || return 1
    if declare -f git_url_toSsh &>/dev/null; then
        ssh_url=${ git_url_toSsh "$url"; } || return 1
    else
        ssh_url="$url"
    fi
    if command -v timeout &>/dev/null; then
        timeout 8 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
}

# Description: Pull (or full-clone) a URL into dest via store + GIT_REPO_* bridge.
# Arguments:
# - url:   <String> Git URL
# - dest:  <String> Destination directory
# - depth: <Int|optional> 1 = store pull (default); 0 = full clone
# Returns:
# - <Bool> 0 on success
nds_git_env_pullTo() {
    local url="${1:-}" dest="${2:-}" depth="${3:-1}"
    local key_path ssh_url safeUrl

    [[ -n "$url" && -n "$dest" ]] || return 1
    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_setTargetDir "$url" "$dest" || return 1

    if [[ "$depth" == "0" ]]; then
        key_path=${ git_store_getKeyPath "$url"; } || true
        ssh_url=${ git_store_getUrlSsh "$url"; } || {
            ssh_url=${ git_url_toSsh "$url"; } || return 1
        }
        mkdir -p "$(dirname "$dest")"
        if declare -f _git_generic_withEnv &>/dev/null; then
            safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
            _git_generic_withEnv "${key_path:-}" clone "$ssh_url" "$dest"
            return $?
        fi
        local -a envv=()
        while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_for_url "$url")
        env "${envv[@]}" git -c credential.helper= clone "$ssh_url" "$dest"
        return $?
    fi

    git_store_pull "$url"
}
