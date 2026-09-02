#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store access plugin (index + query helpers)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-30 | Modified: 2026-09-02
# ==================================================================================================

# Description: Store access defaults, probe isPrivate, overlay keyPath.
# Fields: needWrite, accessVerified, isPrivate, keyPath.
# Arguments:
# - safeUrl: <String> Indexed safeUrl
_git_store_access_index() {
    local safeUrl="$1"
    local isPrivate keyPath

    git_store_set "$safeUrl" needWrite "false"
    git_store_set "$safeUrl" accessVerified "false"

    isPrivate=${ _git_store_api_dispatch isPrivate "$safeUrl"; }
    isPrivate=${ _git_store_parseBool "$isPrivate"; } || {
        err "isPrivate not a boolean: $isPrivate"
        return 1
    }
    git_store_set "$safeUrl" isPrivate "$isPrivate"

    _git_store_overlayEnv "$safeUrl" keyPath targetDir
    keyPath=${ git_store_get "$safeUrl" keyPath; }
    if [[ -z "$keyPath" ]]; then
        git_store_set "$safeUrl" keyPath "${GIT_WORKDIR:?}/keys/${safeUrl}"
    fi
}

# Description: True when the stored keyPath file exists.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when a key file is present
git_store_hasKey() {
    local path
    path=${ git_store_get "$1" keyPath; } || return 1
    [[ -n "$path" && -f "$path" ]]
}

# Description: True when accessVerified is true.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when read is available
git_store_canRead() {
    local accessVerified
    accessVerified=${ git_store_get "$1" accessVerified; } || return 1
    [[ "$accessVerified" == "true" ]]
}

# Description: True when needWrite and accessVerified are both true.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when write is available
git_store_canWrite() {
    local needWrite accessVerified
    needWrite=${ git_store_get "$1" needWrite; } || return 1
    accessVerified=${ git_store_get "$1" accessVerified; }
    [[ "$needWrite" == "true" && "$accessVerified" == "true" ]]
}

# Description: Stored private-key path for a URL.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <String> Key path (stdout)
# - <Bool> 0 when indexed
git_store_getKeyPath() {
    git_store_get "$1" keyPath
}
