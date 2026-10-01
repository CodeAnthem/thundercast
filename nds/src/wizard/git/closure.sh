#!/usr/bin/env bash
# ==================================================================================================
# NDS - Repository access
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-30 | Modified: 2026-09-30
# Description:   Root is read or write. Inputs are read, walked until the set stops.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_access_ensure() {
    local _acc_name=$1 _acc_url=$2 _acc_keys=$3
    declare -f git_probe >/dev/null || return 0
    git_probe "$_acc_keys" "$_acc_url" && return 0
    if nds_mode_is_interactive; then
        _NDS_GIT_AA=$_acc_name
        _nds_git_obtain "$_acc_name" "$_acc_url" || return 1
        git_probe "$_acc_keys" "$_acc_url"
        return
    fi
    error "git: no key for ${_acc_url}"
    return 1
}

_nds_access_checkout() {
    local _acc_keys=$1 _acc_url=$2 _acc_dest=$3
    [[ -d "${_acc_dest}/.git" ]] && return 0
    mkdir -p "$(dirname "$_acc_dest")"
    git_clone "$_acc_keys" "$_acc_url" "$_acc_dest"
}

_nds_access_write() {
    local _acc_dest=$1 _acc_url=$2
    [[ -d "${_acc_dest}/.git" ]] || return 0
    git -C "$_acc_dest" remote get-url origin >/dev/null 2>&1 || return 0
    git -C "$_acc_dest" push --dry-run origin HEAD >/dev/null 2>&1 || {
        error "git: write denied for ${_acc_url}"
        return 1
    }
}

_nds_access_walk_dir() {
    local _acc_name=$1 _acc_dir=$2 _acc_keys=$3
    local -a _acc_queue=("$_acc_dir")
    local _acc_seen="|" _acc_cur _acc_url _acc_safe _acc_sub
    while ((${#_acc_queue[@]})); do
        _acc_cur=${_acc_queue[0]}
        if ((${#_acc_queue[@]} > 1)); then
            _acc_queue=("${_acc_queue[@]:1}")
        else
            _acc_queue=()
        fi
        [[ -f "${_acc_cur}/flake.lock" ]] || continue
        declare -f flake_listLockGitEntries >/dev/null || return 0
        while IFS=$'\t' read -r _acc_url _; do
            [[ -n "$_acc_url" ]] || continue
            [[ "$_acc_seen" == *"|${_acc_url}|"* ]] && continue
            _acc_seen+="${_acc_url}|"
            _nds_access_ensure "$_acc_name" "$_acc_url" "$_acc_keys" || return 1
            _acc_safe=${ git_url_safe "$_acc_url"; } || _acc_safe=repo
            _acc_sub="${ nds_session_dir work; }/access/${_acc_safe}"
            _nds_access_checkout "$_acc_keys" "$_acc_url" "$_acc_sub" || return 1
            _acc_queue+=("$_acc_sub")
        done < <(flake_listLockGitEntries "${_acc_cur}/flake.lock")
    done
}

nds_access_read() {
    _nds_access_go "$1" read "$2"
}

nds_access_write() {
    _nds_access_go "$1" write "$2"
}

nds_access_run() {
    local _acc_line _acc_mode _acc_key
    declare -f action_access >/dev/null || return 0
    _acc_line=${ action_access; }
    _acc_mode=${_acc_line%% *}
    _acc_key=${_acc_line#* }
    [[ "$_acc_mode" == none ]] && return 0
    _nds_access_go "$1" "$_acc_mode" "$_acc_key"
}

_nds_access_go() {
    local _acc_name=$1 _acc_mode=$2 _acc_key=$3 _acc_value _acc_keys _acc_dest
    [[ "$_acc_mode" == read || "$_acc_mode" == write ]] || {
        error "action_access: ${_acc_mode}"
        return 1
    }
    [[ "$_acc_key" == "$_acc_mode" ]] && _acc_key=FLAKE_LOCATION
    _acc_keys=$(nds_recipe_get "$_acc_name" GIT_KEYS_DIR)
    [[ -n "$_acc_keys" ]] || _acc_keys="${ nds_session_dir secrets; }/git"
    mkdir -p "$_acc_keys"
    nds_recipe_set "$_acc_name" GIT_KEYS_DIR "$_acc_keys"
    _acc_value=$(nds_recipe_get "$_acc_name" "$_acc_key")
    if [[ -z "$_acc_value" && "$_acc_key" == FLAKE_LOCATION ]]; then
        _acc_value=$(nds_recipe_get "$_acc_name" FLAKE_REPO_URL)
        [[ -n "$_acc_value" ]] || _acc_value=$(nds_recipe_get "$_acc_name" FLAKE_LOCAL_PATH)
    fi
    if [[ -z "$_acc_value" ]]; then
        if ! nds_mode_is_interactive; then
            error "${_acc_key}: required"
            return 1
        fi
        case "$_acc_key" in
            FLAKE_LOCATION) nds_ask_flakeLocation "$_acc_name" FLAKE_LOCATION || return 1 ;;
            CATALOG_URL) _nds_ask_text "$_acc_name" CATALOG_URL || return 1 ;;
            *)
                error "${_acc_key}: required"
                return 1
                ;;
        esac
        _NDS_ANSWERED[$_acc_key]=1
        _acc_value=$(nds_recipe_get "$_acc_name" "$_acc_key")
    fi
    if declare -f git_url_isRemote >/dev/null && git_url_isRemote "$_acc_value"; then
        if [[ "$_acc_key" == FLAKE_LOCATION ]]; then
            nds_recipe_set "$_acc_name" FLAKE_SOURCE remote
            nds_recipe_set "$_acc_name" FLAKE_REPO_URL "$_acc_value"
        fi
        _nds_access_ensure "$_acc_name" "$_acc_value" "$_acc_keys" || return 1
        if [[ "$_acc_key" == CATALOG_URL ]]; then
            _acc_dest="${ nds_session_dir work; }/catalog"
        else
            _acc_dest="${ nds_session_dir work; }/flake-probe"
        fi
        _nds_access_checkout "$_acc_keys" "$_acc_value" "$_acc_dest" || return 1
        if [[ "$_acc_mode" == write ]]; then
            _nds_access_write "$_acc_dest" "$_acc_value" || return 1
        fi
        _nds_access_walk_dir "$_acc_name" "$_acc_dest" "$_acc_keys" || return 1
        return 0
    fi
    if [[ -d "$_acc_value" ]]; then
        if [[ "$_acc_mode" == write ]]; then
            _nds_access_write "$_acc_value" "$_acc_value" || return 1
        fi
        _nds_access_walk_dir "$_acc_name" "$_acc_value" "$_acc_keys" || return 1
    fi
}
