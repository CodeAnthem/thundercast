#!/usr/bin/env bash
# ==================================================================================================
# Git utility - safeUrl map (raw URL ↔ safeUrl)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-31 | Modified: 2026-08-31
# ==================================================================================================

# rawUrl → safeUrl (and safeUrl → safeUrl for identity lookup)
declare -gA _GIT_SAFE_URLS=()

# Description: True when this URL already has an entry in the safeUrl map.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> 0 when mapped
git_store_safeUrlExists() {
    local url="${1:-}"
    [[ -n "$url" && -n "${_GIT_SAFE_URLS[$url]+_}" ]]
}

# Description: Build safeUrl from a tryParse id array, register raw→safe (and
# safe→safe), print safeUrl.
# Arguments:
# - url: <String> Raw git URL
# - id:  <Nameref> Associative array (host, owner, repoName, …)
# Returns:
# - <String> safeUrl (stdout)
# - <Bool> 0 when registered
_git_store_setSafeUrl() {
    local url="$1"
    local -n _id="$2"
    local safe

    safe="${_id[host]}_${_id[owner]}_${_id[repoName]}"
    safe="${safe//[^A-Za-z0-9]/_}"
    if [[ -z "$safe" ]]; then
        err "empty safeUrl"
        return 1
    fi
    _GIT_SAFE_URLS["$url"]="$safe"
    _GIT_SAFE_URLS["$safe"]="$safe"
    printf '%s' "$safe"
}

# Description: Look up safeUrl for a URL. If unmapped, tryParse and register.
# Prefer git_store_safeUrlExists first when the caller can avoid the parse path
# (e.g. git_store_index).
# Arguments:
# - url: <String> Raw git URL or safeUrl
# Returns:
# - <String> safeUrl (stdout)
# - <Bool> 0 when mapped or registered
git_store_getSafeUrl() {
    local url="${1:-}"
    local -A id=()

    if [[ -z "$url" ]]; then
        err "URL is empty"
        return 1
    fi
    if git_store_safeUrlExists "$url"; then
        printf '%s' "${_GIT_SAFE_URLS[$url]}"
        return 0
    fi
    _git_url_tryParse id "$url" || { err "Unable to parse URL: $url"; return 1; }
    _git_store_setSafeUrl "$url" id
}
