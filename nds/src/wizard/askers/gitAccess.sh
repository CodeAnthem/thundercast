#!/usr/bin/env bash
# ==================================================================================================
# NDS - Git access asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_git_collect_urls() {
    local _git_name=$1 _git_url _git_root _git_line _git_seen="|"
    _git_url=$(nds_recipe_get "$_git_name" FLAKE_REPO_URL)
    if [[ -n "$_git_url" ]]; then
        printf '%s\n' "$_git_url"
        _git_seen+="${_git_url}|"
    fi
    _git_root=$(_nds_ask_flake_root "$_git_name")
    [[ -f "${_git_root}/flake.lock" ]] || return 0
    declare -f flake_listLockGitEntries >/dev/null || return 0
    while IFS=$'\t' read -r _git_url _ _git_line; do
        [[ -n "$_git_url" ]] || continue
        [[ "$_git_seen" == *"|${_git_url}|"* ]] && continue
        printf '%s\n' "$_git_url"
        _git_seen+="${_git_url}|"
    done < <(flake_listLockGitEntries "${_git_root}/flake.lock")
}

nds_ask_gitAccess() {
    local _git_name=$1 _git_key=$2 _git_dir _git_url _git_rc=0
    _NDS_GIT_AA=$_git_name
    _git_dir=$(nds_recipe_get "$_git_name" "$_git_key")
    [[ -n "$_git_dir" ]] || _git_dir="${ nds_session_dir secrets; }/git"
    mkdir -p "$_git_dir"
    nds_recipe_set "$_git_name" "$_git_key" "$_git_dir"
    while IFS= read -r _git_url; do
        [[ -n "$_git_url" ]] || continue
        if declare -f git_probe >/dev/null && git_probe "$_git_dir" "$_git_url"; then
            continue
        fi
        _nds_git_obtain "$_git_name" "$_git_url" || _git_rc=$?
        [[ "$_git_rc" -eq 0 ]] || return "$_git_rc"
    done < <(_nds_git_collect_urls "$_git_name")
}
