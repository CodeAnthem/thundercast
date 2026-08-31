#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git store env bridge (GIT_REPO_* ↔ NDS keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# Description:   Maintain GIT_REPO_<safeUrl>_keyPath|targetDir for the git utility store
# ==================================================================================================

# Description: Export GIT_REPO_<safe>_keyPath and write store keyPath.
# Arguments:
# - url:     <String> Git remote URL
# - keyPath: <String> Private key path
# Returns:
# - <Bool> 0 when indexed and set
nds_git_env_setKeyPath() {
    local url="${1:-}" keyPath="${2:-}" safeUrl
    [[ -n "$url" && -n "$keyPath" ]] || return 1
    declare -f git_store_getSafeUrl &>/dev/null || return 1
    git_store_index "$url" || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    export "GIT_REPO_${safeUrl}_keyPath=${keyPath}"
    git_store_set "$url" keyPath "$keyPath"
}

# Description: Export GIT_REPO_<safe>_targetDir and write store targetDir.
# Arguments:
# - url: <String> Git remote URL
# - dir: <String> Clone / worktree directory
# Returns:
# - <Bool> 0 when indexed and set
nds_git_env_setTargetDir() {
    local url="${1:-}" dir="${2:-}" safeUrl
    [[ -n "$url" && -n "$dir" ]] || return 1
    declare -f git_store_getSafeUrl &>/dev/null || return 1
    git_store_index "$url" || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    export "GIT_REPO_${safeUrl}_targetDir=${dir}"
    git_store_set "$url" targetDir "$dir"
}

# Description: If store already has a real keyPath file, export GIT_REPO_*_keyPath.
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <Bool> 0 when exported
nds_git_env_bindFromStore() {
    local url="${1:-}" keyPath safeUrl
    [[ -n "$url" ]] || return 1
    declare -f git_store_hasKey &>/dev/null || return 1
    git_store_hasKey "$url" || return 1
    keyPath=${ git_store_getKeyPath "$url"; } || return 1
    safeUrl=${ git_store_getSafeUrl "$url"; } || return 1
    export "GIT_REPO_${safeUrl}_keyPath=${keyPath}"
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
        if declare -f _nds_git_url_toSsh &>/dev/null; then
            norm=$(_nds_git_url_toSsh "$url")
        else
            norm="$url"
        fi
        keyPath="${NDS_GIT_KEY_PATH[$norm]:-}"
        [[ -z "$keyPath" || ! -f "$keyPath" ]] && keyPath="${NDS_GIT_KEY_PATH[$url]:-}"
    fi
    if [[ -z "$keyPath" || ! -f "$keyPath" ]] \
        && declare -f _nds_git_identity_for_url &>/dev/null; then
        keyPath=$(_nds_git_identity_for_url "$url" 2>/dev/null || true)
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
