#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git SSH environment
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-05 | Modified: 2026-08-28
# Description:   Per-repo SSH env for git probes and Nix prefetch (registered keys as ssh -i)
# ==================================================================================================

# Description: No-op — kept for callers after key registration.
nds_git_ssh_config_refresh() {
    :
}

# Description: Best private key path for a git remote URL (deploy key per repo first).
# Arguments:
# - url: <String> Git remote URL
# Returns:
# - <String> Private key path (stdout), non-zero when none found
_nds_git_identity_for_url() {
    local url="$1" ssh_url parsed host owner repo key base reg_key

    ssh_url=$(_nds_git_url_toSsh "$url")
    parsed=$(_nds_git_url_parse "$ssh_url") || return 1
    IFS=$'\t' read -r host owner repo <<< "$parsed"
    key="$(nds_git_deploy_key_path "$owner" "$repo" 2>/dev/null || true)"
    [[ -f "$key" ]] && {
        printf '%s\n' "$key"
        return 0
    }
    base="$(nds_git_deploy_key_basename "$owner" "$repo" 2>/dev/null || true)"
    if [[ -n "$base" ]]; then
        while IFS= read -r reg_key; do
            [[ -f "$reg_key" && "$(basename "$reg_key")" == "$base" ]] && {
                printf '%s\n' "$reg_key"
                return 0
            }
        done < <(nds_git_keys_list 2>/dev/null || true)
    fi
    while IFS= read -r reg_key; do
        [[ -f "$reg_key" ]] || continue
        printf '%s\n' "$reg_key"
        return 0
    done < <(nds_git_keys_list 2>/dev/null || true)
    key="$(nds_git_session_key_path 2>/dev/null || true)"
    [[ -n "$key" && -f "$key" ]] && {
        printf '%s\n' "$key"
        return 0
    }
    return 1
}

# Description: Private key paths to offer for a URL (registered keys first, then dest).
# Arguments:
# - url: <String|optional> Git remote URL
# Returns:
# - <String> paths (stdout, one per line)
_nds_git_ssh_identity_paths() {
    local url="${1:-}" key=""

    {
        nds_git_keys_list 2>/dev/null || true
        if [[ -n "$url" ]]; then
            key="$(_nds_git_identity_for_url "$url" 2>/dev/null || true)"
            [[ -n "$key" && -f "$key" ]] && printf '%s\n' "$key"
        fi
    } | awk 'NF && !seen[$0]++'
}

# Description: GIT_SSH_COMMAND for one repository (all registered keys, then dest).
# Arguments:
# - url: <String> Git remote URL
_nds_git_ssh_env_for_url() {
    local url="$1"
    local -a keys=()

    mapfile -t keys < <(_nds_git_ssh_identity_paths "$url")
    if [[ ${#keys[@]} -eq 0 ]]; then
        _nds_git_ssh_env
        return 0
    fi
    nds_git_ssh_env_for_keys "${keys[@]}"
}

# Description: GIT_SSH_COMMAND fallback (every registered key, else session, else bare).
_nds_git_ssh_env() {
    local key_path
    local -a keys=()

    mapfile -t keys < <(nds_git_keys_list 2>/dev/null || true)
    if [[ ${#keys[@]} -gt 0 ]]; then
        nds_git_ssh_env_for_keys "${keys[@]}"
        return 0
    fi

    key_path="$(nds_git_session_key_path 2>/dev/null || true)"
    if [[ -n "$key_path" && -f "$key_path" ]]; then
        nds_git_ssh_env_for_key "$key_path"
        return 0
    fi

    nds_git_ssh_env_bare
}

# Description: Mark git access as verified for this session (closure complete).
nds_git_access_mark_verified() {
    NDS_GIT_ACCESS_VERIFIED=true
    export NDS_GIT_ACCESS_VERIFIED
}

# Description: True when git auth/closure checks already passed in this session.
nds_git_access_verified() {
    [[ "${NDS_GIT_ACCESS_VERIFIED:-}" == "true" ]]
}
