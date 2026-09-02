#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git probe (framework → store verify)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-09-01
# Description:   Quiet store verify for NDS wizard / discover (clone lives on bridge)
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
    key_path=${ _nds_git_identity_for_url "$url" 2>/dev/null || true; }
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
