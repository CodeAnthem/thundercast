#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access URL, key, and route helpers
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_git_access_cfg_get() {
    local _git_key=$1 _git_val=""
    if [[ "$_git_key" == FLAKE_REPO_URL && -n ${NDS_FLAKE_REPO_URL:-} ]]; then
        printf '%s\n' "$NDS_FLAKE_REPO_URL"
        return 0
    fi
    if [[ -n ${_NDS_GIT_AA:-} ]]; then
        _git_val=$(nds_recipe_get "$_NDS_GIT_AA" "$_git_key")
    fi
    printf '%s\n' "$_git_val"
}

nds_git_access_normalize_need() {
    case "${1,,}" in
        write|rw|push) printf 'write\n' ;;
        *) printf 'read\n' ;;
    esac
}

nds_git_access_is_need_target() {
    local _git_owner=$1 _git_repo=$2 _git_url _git_parsed _git_leaf_owner _git_leaf_repo
    _git_url=$(_nds_git_access_cfg_get FLAKE_REPO_URL)
    [[ -n "$_git_url" ]] || return 1
    _git_parsed=$(_nds_git_url_parse "$(_nds_git_url_toSsh "$_git_url")") || return 1
    IFS=$'\t' read -r _ _git_leaf_owner _git_leaf_repo <<< "$_git_parsed"
    [[ "${_git_owner,,}" == "${_git_leaf_owner,,}" && "${_git_repo,,}" == "${_git_leaf_repo,,}" ]]
}

nds_git_access_deploy_read_only() {
    local _git_owner=$1 _git_repo=$2 _git_need=$3
    if [[ $(nds_git_access_normalize_need "$_git_need") == write ]] \
        && nds_git_access_is_need_target "$_git_owner" "$_git_repo"; then
        printf 'false\n'
    else
        printf 'true\n'
    fi
}

nds_git_access_logic_normalize() {
    local -n _git_cfg=$1
    local _git_url _git_parsed _git_host _git_owner _git_repo _git_ssh
    _git_url=${_git_cfg[FLAKE_REPO_URL]:-}
    [[ -n "$_git_url" ]] || return 1
    case "$_git_url" in
        http://*|https://*|git://*|ssh://*|*@*:*) ;;
        *) return 1 ;;
    esac
    if _git_parsed=$(_nds_git_url_parse "$_git_url"); then
        IFS=$'\t' read -r _git_host _git_owner _git_repo <<< "$_git_parsed"
        if [[ "$_git_url" != git@* && "$_git_url" != ssh://* ]]; then
            _git_ssh=$(_nds_git_url_formatSsh "$_git_host" "$_git_owner" "$_git_repo")
            _git_cfg[FLAKE_REPO_URL]=$_git_ssh
            _git_cfg[FLAKE_LOCATION]=$_git_ssh
            _git_cfg[FLAKE_LOCAL_PATH]=""
            _git_cfg[FLAKE_SOURCE]=remote
        fi
        _git_cfg[GIT_ACCESS_HOST]=$_git_host
        _git_cfg[GIT_ACCESS_OWNER]=$_git_owner
        _git_cfg[GIT_ACCESS_REPO]=$_git_repo
    fi
}

nds_git_access_wants_gh_ui() {
    local -n _git_gh=$1
    local _git_method=${_git_gh[GIT_SSH_KEY_REGISTER_METHOD]:-${_git_gh[GIT_SSH_KEY_TYPE]:-}}
    local _git_kind=${_git_gh[GIT_AUTH_MODE]:-}
    [[ "${_git_method,,}" == *gh* || "${_git_method,,}" == account \
        || "${_git_kind,,}" == gh || "${_git_kind,,}" == account ]]
}

nds_git_auth_prompts() {
    local -n _git_p=$1
    local _git_need=${2:-read} _git_reason=${3:-}
    local _git_host=${_git_p[GIT_ACCESS_HOST]:-}
    local _git_owner=${_git_p[GIT_ACCESS_OWNER]:-}
    local _git_repo=${_git_p[GIT_ACCESS_REPO]:-}
    if [[ -z "$_git_host" || -z "$_git_owner" || -z "$_git_repo" ]]; then
        error "Git auth prompts need GIT_ACCESS_HOST/OWNER/REPO in config AA"
        return 1
    fi
    nds_git_auth_wizard_step_repo "$_git_host" "$_git_owner" "$_git_repo" "$_git_need" "$_git_reason"
}

nds_git_auth_wizard_step_repo() {
    local _git_host=$1 _git_owner=$2 _git_repo=$3 _git_need=$4 _git_reason=${5:-}
    local _git_url
    ui_h "Git access"
    [[ -n "$_git_reason" ]] && ui_b "$_git_reason"
    ui_kv "Need" "$(nds_git_access_normalize_need "$_git_need")"
    _git_url=$(_nds_git_url_formatSsh "$_git_host" "$_git_owner" "$_git_repo")
    if [[ -n ${_NDS_GIT_AA:-} ]]; then
        _nds_git_obtain "$_NDS_GIT_AA" "$_git_url" || return 1
    fi
}
