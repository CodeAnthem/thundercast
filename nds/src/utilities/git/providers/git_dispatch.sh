#!/usr/bin/env bash
# ==================================================================================================
# Git utility - provider dispatch (provider_<op> else generic_<op>)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-29 | Modified: 2026-08-31
# ==================================================================================================

# Description: Call git_<provider>_<op> or git_generic_<op> for a URL.
# Arguments:
# - op:  <String> Provider function suffix
# - url: <String> Raw URL or safeUrl
# Returns:
# - <Int> Provider return code
_git_store_api_dispatch() {
    local op="$1"
    local url="$2"
    local provider fn
    shift 2

    provider=${ git_store_get "$url" provider; } || return 1
    if [[ -z "$provider" ]]; then
        err "provider missing for $url"
        return 1
    fi
    fn="git_${provider}_${op}"
    if declare -f "$fn" >/dev/null; then
        "$fn" "$url" "$@"
    else
        "git_generic_${op}" "$url" "$@"
    fi
}
