#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git URL helpers for the access screens
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_git_url_parse() {
    local _git_url=$1
    if declare -f git_url_parse >/dev/null; then
        local _git_host _git_owner _git_repo _git_rest
        local _git_line
        _git_line=${ git_url_parse "$_git_url"; } || return 1
        IFS=$'\t' read -r _git_host _git_owner _git_repo _git_rest <<< "$_git_line"
        [[ -n "$_git_owner" && -n "$_git_repo" ]] || return 1
        printf '%s\t%s\t%s\n' "$_git_host" "$_git_owner" "$_git_repo"
        return 0
    fi
    local _git_host _git_owner _git_repo
    if [[ "$_git_url" =~ ^https?://([^/]+)/([^/]+)/([^/.]+)(\.git)?/?$ ]]; then
        _git_host=${BASH_REMATCH[1]}
        _git_owner=${BASH_REMATCH[2]}
        _git_repo=${BASH_REMATCH[3]}
    elif [[ "$_git_url" =~ ^git@([^:]+):([^/]+)/([^/.]+)(\.git)?$ ]]; then
        _git_host=${BASH_REMATCH[1]}
        _git_owner=${BASH_REMATCH[2]}
        _git_repo=${BASH_REMATCH[3]}
    else
        return 1
    fi
    printf '%s\t%s\t%s\n' "$_git_host" "$_git_owner" "$_git_repo"
}

_nds_git_url_formatSsh() {
    printf 'git@%s:%s/%s.git\n' "$1" "$2" "$3"
}

_nds_git_url_toSsh() {
    local _git_parsed _git_host _git_owner _git_repo
    _git_parsed=$(_nds_git_url_parse "$1") || {
        printf '%s\n' "$1"
        return 0
    }
    IFS=$'\t' read -r _git_host _git_owner _git_repo <<< "$_git_parsed"
    _nds_git_url_formatSsh "$_git_host" "$_git_owner" "$_git_repo"
}

_nds_git_safe() {
    if declare -f git_url_safe >/dev/null; then
        git_url_safe "$1" && return 0
    fi
    local _git_safe=${1,,}
    _git_safe=${_git_safe//[^a-z0-9]/_}
    printf '%s\n' "$_git_safe"
}
