#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe store
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Get and set on a named associative array. No global recipe.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

declare -gA _NDS_ANSWERED=()

nds_recipe_get() {
    local -n _nds_recipe_aa=$1
    local _nds_recipe_key=$2
    if [[ -v "_nds_recipe_aa[$_nds_recipe_key]" ]]; then
        printf '%s\n' "${_nds_recipe_aa[$_nds_recipe_key]}"
    else
        printf '%s\n' "${3-}"
    fi
}

nds_default() {
    nds_recipe_has "$1" "$2" && return 0
    nds_recipe_set "$1" "$2" "$3"
}

nds_pin() {
    nds_recipe_set "$1" "$2" "$3"
    nds_schema_lock "$2"
    _NDS_ANSWERED[$2]=1
}

nds_recipe_set() {
    local -n _nds_recipe_set_aa=$1
    if [[ ${_NDS_SCHEMA_ATTR[$2|locked]:-} == 1 ]]; then
        [[ ${_nds_recipe_set_aa[$2]:-} == "$3" ]] && return 0
        error "$2: locked"
        return 1
    fi
    _nds_recipe_set_aa[$2]=$3
    if [[ ${_NDS_MARK_ANSWERED:-} == 1 ]]; then
        _NDS_ANSWERED[$2]=1
    fi
}

nds_recipe_has() {
    local -n _nds_recipe_aa=$1
    [[ -v "_nds_recipe_aa[$2]" && -n ${_nds_recipe_aa[$2]} ]]
}

nds_recipe_is() {
    local -n _nds_recipe_aa=$1
    [[ -v "_nds_recipe_aa[$2]" && ${_nds_recipe_aa[$2]} == "$3" ]]
}

nds_recipe_true() {
    local -n _nds_recipe_aa=$1
    [[ -v "_nds_recipe_aa[$2]" && ${_nds_recipe_aa[$2]} == true ]]
}

nds_recipe_keys() {
    local -n _nds_recipe_aa=$1
    local _nds_recipe_key
    local -a _nds_recipe_keys=()
    for _nds_recipe_key in "${!_nds_recipe_aa[@]}"; do
        _nds_recipe_keys+=("$_nds_recipe_key")
    done
    if ((${#_nds_recipe_keys[@]} == 0)); then
        return 0
    fi
    printf '%s\n' "${_nds_recipe_keys[@]}" | sort
}
