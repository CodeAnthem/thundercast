#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe and clone (framework)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-31
# Description:   Thin wrappers over git store verify/pull (+ depth-0 clone)
# ==================================================================================================

# Description: True when a repo is accessible with the current NDS / store key.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" key_path=""
    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_bindFromStore "$url" 2>/dev/null || true
    git_store_needWrite "$url" false || return 1
    if _nds_git_env_verifyQuiet "$url"; then
        return 0
    fi
    key_path=$(_nds_git_identity_for_url "$url" 2>/dev/null || true)
    debug "git probe failed: ${url} key=${key_path:-none}"
    nds_install_log "git: probe failed ${url} (key=${key_path:-none})"
    return 1
}

# Description: Probe a URL with an explicit private key (not identity_for_url).
# Arguments:
# - url:      <String> Git URL
# - key_path: <String> Private key path
# Returns:
# - <Bool> 0 when access succeeds with that identity
nds_git_probe_access_with_key() {
    local url="$1" key_path="$2"

    [[ -f "$key_path" ]] || return 1
    nds_git_env_setKeyPath "$url" "$key_path" || return 1
    git_store_needWrite "$url" false || return 1
    _nds_git_env_verifyQuiet "$url"
}

# Description: Clone a flake using store pull (depth 1) or full git clone (depth 0).
# Arguments:
# - url:   <String> Git URL (HTTPS URLs are converted to SSH when parseable)
# - dest:  <String> Destination directory
# - depth: <Int|optional> Clone depth (default 1; 0 = full clone)
# Returns:
# - <Bool> 0 on success
nds_git_clone() {
    local url="$1" dest="$2" depth="${3:-1}"
    local key_path ssh_url safeUrl

    nds_git_env_syncKeyFromNds "$url" 2>/dev/null || true
    nds_git_env_setTargetDir "$url" "$dest" || return 1

    if [[ "$depth" == "0" ]]; then
        key_path=${ git_store_getKeyPath "$url"; } || true
        ssh_url=${ git_store_getUrlSsh "$url"; } || ssh_url=$(_nds_git_url_toSsh "$url")
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
