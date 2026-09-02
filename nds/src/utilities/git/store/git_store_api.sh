#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store action API (needWrite, verifyAccess, pull, push, deploy keys)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-09-02
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

# Description: Satisfy needWrite from store fields / key probe. Never prompts.
# On failure sets GIT_STORE_LAST_ERROR to auth|unreachable|error.
# Arguments:
# - url:    <String> Raw URL or safeUrl
# - reason: <String|optional> Ignored (kept for call-site compat)
# Returns:
# - <Bool> 0 when access is satisfied
git_store_verifyAccess() {
    local url="$1"
    local key_path isPrivate needWrite

    _git_store_setLastError ""
    needWrite=${ git_store_get "$url" needWrite; } || {
        _git_store_setLastError "error"
        return 1
    }
    if [[ "$needWrite" == "true" ]]; then
        git_store_canWrite "$url" && return 0
    elif git_store_canRead "$url"; then
        return 0
    fi

    if git_store_hasKey "$url"; then
        key_path=${ git_store_getKeyPath "$url"; }
        if _git_store_api_dispatch probeWithKey "$url" "$key_path"; then
            return 0
        fi
        _git_store_failAccess "$url"
        return 1
    fi

    if git_store_canRead "$url" && [[ "$needWrite" != "true" ]]; then
        return 0
    fi

    isPrivate=${ git_store_get "$url" isPrivate; }
    if [[ -z "$isPrivate" || "$isPrivate" == "unknown" ]]; then
        isPrivate=${ _git_store_api_dispatch isPrivate "$url"; }
        isPrivate=${ _git_store_parseBool "$isPrivate"; } || {
            _git_store_setLastError "error"
            return 1
        }
        git_store_set "$url" isPrivate "$isPrivate"
    fi
    if [[ "$isPrivate" == "false" && "$needWrite" != "true" ]]; then
        git_store_set "$url" accessVerified "true"
        return 0
    fi

    if [[ "$isPrivate" != "true" ]] && _git_store_api_dispatch probeWithKey "$url" ""; then
        return 0
    fi

    _git_store_failAccess "$url"
    return 1
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
