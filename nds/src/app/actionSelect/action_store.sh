#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action stores
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-24 | Modified: 2026-09-25
# Description:   local is builtins and fleet. remote is a catalog directory passed to discover.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -ga _NDS_ACTION_ORDER_LOCAL=()
declare -gA _NDS_ACTION_DATA_LOCAL=()
declare -ga _NDS_ACTION_ORDER_REMOTE=()
declare -gA _NDS_ACTION_DATA_REMOTE=()

# First name wins. path is the script discover will source.
_nds_action_store_add() {
    local store="$1" name="$2" path="$3" description="${4:-}"
    local -n _order _data
    case "$store" in
        local) _order=_NDS_ACTION_ORDER_LOCAL; _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _order=_NDS_ACTION_ORDER_REMOTE; _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    [[ -n "${_data[${name}.path]:-}" ]] && return 0
    _order+=("$name")
    _data["${name}.path"]="$path"
    _data["${name}.description"]="$description"
}

_nds_action_store_remove() {
    local store="$1" name="$2" item
    local -n _order _data
    case "$store" in
        local) _order=_NDS_ACTION_ORDER_LOCAL; _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _order=_NDS_ACTION_ORDER_REMOTE; _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    local -a next=()
    for item in "${_order[@]+"${_order[@]}"}"; do
        [[ "$item" == "$name" ]] && continue
        next+=("$item")
    done
    if [[ ${#next[@]} -eq 0 ]]; then
        _order=()
    else
        _order=("${next[@]}")
    fi
    unset "_data[${name}.path]" "_data[${name}.description]"
}

_nds_action_store_clear() {
    local store="$1"
    local -n _order _data
    case "$store" in
        local) _order=_NDS_ACTION_ORDER_LOCAL; _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _order=_NDS_ACTION_ORDER_REMOTE; _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    _order=()
    _data=()
}

_nds_action_store_empty() {
    local store="$1"
    local -n _order
    case "$store" in
        local) _order=_NDS_ACTION_ORDER_LOCAL ;;
        remote) _order=_NDS_ACTION_ORDER_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    [[ ${#_order[@]} -eq 0 ]]
}

_nds_action_store_has() {
    local store="$1" name="$2"
    local -n _data
    case "$store" in
        local) _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    [[ -n "${_data[${name}.path]:-}" ]]
}

_nds_action_store_names() {
    local store="$1" name
    local -n _order
    case "$store" in
        local) _order=_NDS_ACTION_ORDER_LOCAL ;;
        remote) _order=_NDS_ACTION_ORDER_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    for name in "${_order[@]+"${_order[@]}"}"; do
        printf '%s\n' "$name"
    done
}

_nds_action_store_path() {
    local store="$1" name="$2"
    local -n _data
    case "$store" in
        local) _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    printf '%s\n' "${_data[${name}.path]:-}"
}

_nds_action_store_description() {
    local store="$1" name="$2"
    local -n _data
    case "$store" in
        local) _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    printf '%s\n' "${_data[${name}.description]:-}"
}

_nds_action_store_set_description() {
    local store="$1" name="$2" description="$3"
    local -n _data
    case "$store" in
        local) _data=_NDS_ACTION_DATA_LOCAL ;;
        remote) _data=_NDS_ACTION_DATA_REMOTE ;;
        *) error "Unknown action store: ${store}"; return 1 ;;
    esac
    _data["${name}.description"]="$description"
}

# Directories under root that contain setup.sh. Does not read the file.
_nds_action_collect() {
    local store="$1" root="$2" dir name setup
    [[ -d "$root" ]] || return 0
    for dir in "$root"/*/; do
        [[ -d "$dir" ]] || continue
        dir="${dir%/}"
        setup="${dir}/setup.sh"
        [[ -f "$setup" ]] || continue
        name="${dir##*/}"
        _nds_action_store_add "$store" "$name" "$setup"
    done
}
