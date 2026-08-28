#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe and clone (framework)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-28
# Description:   Identity-aware probe/clone wrapping standalone helpers
# ==================================================================================================

# Description: True when a repo is accessible with the current NDS identity map.
# Arguments:
# - url: <String> Git URL
# Returns:
# - <Bool> 0 when accessible
nds_git_probe_access() {
    local url="$1" ssh_url key_path=""
    ssh_url=$(_nds_git_url_toSsh "$url")
    local -a envv=()
    key_path=$(_nds_git_identity_for_url "$url" 2>/dev/null || true)
    while IFS= read -r line; do envv+=("$line"); done < <(_nds_git_ssh_env_for_url "$url")
    if command -v timeout &>/dev/null; then
        timeout 15 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        debug "git probe failed: ${ssh_url} key=${key_path:-none}"
        nds_install_log "git: probe failed ${ssh_url} (key=${key_path:-none})"
    fi
    return "$rc"
}

# Description: Probe a URL with an explicit private key (not identity_for_url).
# Arguments:
# - url:      <String> Git URL
# - key_path: <String> Private key path
# Returns:
# - <Bool> 0 when ls-remote succeeds with that identity
nds_git_probe_access_with_key() {
    local url="$1" key_path="$2" ssh_url
    local -a envv=()

    [[ -f "$key_path" ]] || return 1
    ssh_url=$(_nds_git_url_toSsh "$url")
    while IFS= read -r line; do envv+=("$line"); done < <(nds_git_ssh_env_for_key "$key_path")
    if command -v timeout &>/dev/null; then
        timeout 15 env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    else
        env "${envv[@]}" git -c credential.helper= ls-remote "$ssh_url" &>/dev/null
    fi
}

# Description: Clone a flake using resolved SSH deploy-key auth.
# Arguments:
# - url:   <String> Git URL (HTTPS URLs are converted to SSH when parseable)
# - dest:  <String> Destination directory
# - depth: <Int|optional> Clone depth (default 1; 0 = full clone)
# Returns:
# - <Bool> 0 on success
nds_git_clone() {
    local url="$1" dest="$2" depth="${3:-1}" key_path=""
    key_path=$(_nds_git_identity_for_url "$url" 2>/dev/null || true)
    nds_git_clone_with_key "$url" "$dest" "$depth" "$key_path"
}
