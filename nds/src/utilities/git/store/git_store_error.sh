#!/usr/bin/env bash
# ==================================================================================================
# Git utility - store last-error + host reachability (internal)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-02 | Modified: 2026-09-02
# ==================================================================================================

declare -g GIT_STORE_LAST_ERROR=""

# Description: Record last store/API failure kind for the caller.
# Arguments:
# - kind: <String> auth|unreachable|error
_git_store_setLastError() {
    GIT_STORE_LAST_ERROR="${1:-error}"
    export GIT_STORE_LAST_ERROR
}

# Description: True when host accepts TCP on 443 or 22 (internal classify helper).
# Arguments:
# - host: <String> Hostname
# Returns:
# - <Bool> 0 when reachable
_git_host_isReachable() {
    local host="${1:-}" port
    [[ -n "$host" ]] || return 1
    for port in 443 22; do
        if command -v timeout &>/dev/null; then
            timeout 3 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null && return 0
        else
            (echo >/dev/tcp/"${host}/${port}") 2>/dev/null && return 0
        fi
    done
    return 1
}

# Description: Set GIT_STORE_LAST_ERROR from reachability and print err.
# Arguments:
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Bool> always 1
_git_store_failAccess() {
    local url="${1:-}" host=""
    host=${ git_store_get "$url" host 2>/dev/null; } || host=""
    if [[ -n "$host" ]] && _git_host_isReachable "$host"; then
        _git_store_setLastError "auth"
        err "access not satisfied (auth)"
    else
        _git_store_setLastError "unreachable"
        err "access not satisfied (unreachable)"
    fi
    return 1
}
