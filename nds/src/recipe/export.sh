#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe seal and export
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Write a deterministic recipe file. Seal refuses an invalid recipe.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_recipe_portableSkip() {
    local _nds_exp_key=$1
    case "$_nds_exp_key" in
        DISK_TARGET|REMOTE_TARGET_IP|GIT_KEYS_DIR|LEAF_PUSH_DIR|LEAF_PUSH_MESSAGE|TARGET_SEED_DIR)
            return 0
            ;;
    esac
    [[ ${_NDS_SCHEMA_FIELD_TYPE[$_nds_exp_key]:-} == secret ]]
}

nds_recipe_export() {
    local _nds_exp_name=$1 _nds_exp_out=$2 _nds_exp_portable=0
    local -n _nds_exp_aa=$1
    local _nds_exp_group _nds_exp_key _nds_exp_wrote _nds_exp_block _nds_exp_tmp _nds_exp_escaped
    [[ ${3:-} == --portable ]] && _nds_exp_portable=1
    _nds_exp_tmp=$(mktemp)
    {
        printf '%s\n' '# nds-recipe 1'
        while IFS= read -r _nds_exp_group; do
            [[ -n "$_nds_exp_group" ]] || continue
            nds_schema_groupIsActive "$_nds_exp_name" "$_nds_exp_group" || continue
            _nds_exp_wrote=0
            _nds_exp_block=""
            while IFS= read -r _nds_exp_key; do
                [[ -n "$_nds_exp_key" ]] || continue
                nds_schema_isActive "$_nds_exp_name" "$_nds_exp_key" || continue
                [[ -n ${_nds_exp_aa[$_nds_exp_key]:-} ]] || continue
                if (( _nds_exp_portable )) && _nds_recipe_portableSkip "$_nds_exp_key"; then
                    continue
                fi
                _nds_exp_escaped=${ _nds_recipe_escape "${_nds_exp_aa[$_nds_exp_key]}"; }
                _nds_exp_block+="${_nds_exp_key}=\"${_nds_exp_escaped}\""$'\n'
                _nds_exp_wrote=1
            done < <(nds_schema_groupFields "$_nds_exp_group")
            if (( _nds_exp_wrote )); then
                printf '[%s]\n' "$_nds_exp_group"
                printf '%s' "$_nds_exp_block"
            fi
        done < <(nds_schema_groups)
    } > "$_nds_exp_tmp"
    mv "$_nds_exp_tmp" "$_nds_exp_out"
}

nds_recipe_seal() {
    local _nds_exp_name=$1 _nds_exp_out=$2 _nds_exp_n=0
    nds_recipe_validate "$_nds_exp_name" || _nds_exp_n=$?
    if (( _nds_exp_n != 0 )); then
        return 1
    fi
    nds_recipe_export "$_nds_exp_name" "$_nds_exp_out" || return 1
    chmod 600 "$_nds_exp_out"
}
