#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store action API (needWrite, verifyAccess, pull, push, deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: Set needWrite for a URL. Index default is false.
# Arguments:
# - url:  <String> Raw URL or safeUrl
# - need: <String> true|false (default true — calling this means write)
# Returns:
# - <Bool> 0 when indexed and set
git_store_needWrite() {
    local url="$1"
    local need="${2:-true}"
    need=${ _git_store_parseBool "$need"; } || return 1
    git_store_set "$url" needWrite "$need"
}

# Description: Satisfy needWrite: stored flags, key file, else prompt.
# Arguments:
# - url:    <String> Raw URL or safeUrl
# - reason: <String|optional> Shown in the prompt
# Returns:
# - <Bool> 0 when access is satisfied
git_store_verifyAccess() {
    local url="$1"
    local reason="${2:-}"
    local key_path isPrivate needWrite

    needWrite=${ git_store_get "$url" needWrite; } || return 1
    if [[ "$needWrite" == "true" ]]; then
        git_store_canWrite "$url" && return 0
    elif git_store_canRead "$url"; then
        return 0
    fi

    if git_store_hasKey "$url"; then
        key_path=${ git_store_getKeyPath "$url"; }
        _git_store_api_dispatch probeWithKey "$url" "$key_path" && return 0
    fi

    if git_store_canRead "$url" && [[ "$needWrite" != "true" ]]; then
        return 0
    fi

    isPrivate=${ git_store_get "$url" isPrivate; }
    if [[ -z "$isPrivate" || "$isPrivate" == "unknown" ]]; then
        isPrivate=${ _git_store_api_dispatch isPrivate "$url"; }
        isPrivate=${ _git_store_parseBool "$isPrivate"; } || return 1
        git_store_set "$url" isPrivate "$isPrivate"
    fi
    if [[ "$isPrivate" == "false" && "$needWrite" != "true" ]]; then
        git_store_set "$url" accessVerified "true"
        return 0
    fi

    if [[ "$isPrivate" != "true" ]] && _git_store_api_dispatch probeWithKey "$url" ""; then
        return 0
    fi

    git_helper_interactive_isEnabled || {
        err "access not satisfied (interactive off)"
        return 1
    }
    _git_store_api_dispatch promptAccess "$url" "$reason"
}

# Description: Add a deploy key via the provider (GitHub: gh).
# Arguments:
# - url:   <String> Raw URL or safeUrl
# - pub:   <String|optional> .pub path
# - title: <String|optional>
# Returns:
# - <Bool> 0 on success
git_store_addDeployKey() {
    _git_store_api_dispatch addDeployKey "$1" "${2:-}" "${3:-}"
}

# Description: Remove a deploy key via the provider.
# Arguments:
# - url:   <String> Raw URL or safeUrl
# - title: <String|optional>
# Returns:
# - <Bool> 0 on success
git_store_removeDeployKey() {
    _git_store_api_dispatch removeDeployKey "$1" "${2:-}"
}

# Description: Provider pull/fetch/clone. Does not check access.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 on success
git_store_pull() {
    _git_store_api_dispatch pull "$1"
}

# Description: Provider push. Does not check access.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 on success
git_store_push() {
    _git_store_api_dispatch push "$1"
}
