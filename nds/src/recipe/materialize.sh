#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe materialize
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Generate empty secret files whose --generate-when holds.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_recipe_materialize() {
    local _nds_mat_name=$1
    local -n _nds_mat_aa=$1
    local _nds_mat_group _nds_mat_key _nds_mat_fn _nds_mat_when _nds_mat_dest
    while IFS= read -r _nds_mat_group; do
        [[ -n "$_nds_mat_group" ]] || continue
        while IFS= read -r _nds_mat_key; do
            [[ -n "$_nds_mat_key" ]] || continue
            [[ ${_NDS_SCHEMA_FIELD_TYPE[$_nds_mat_key]} == secret ]] || continue
            nds_schema_isActive "$_nds_mat_name" "$_nds_mat_key" || continue
            _nds_mat_fn=${_NDS_SCHEMA_ATTR[$_nds_mat_key|generate]:-}
            [[ -n "$_nds_mat_fn" ]] || continue
            [[ -z ${_nds_mat_aa[$_nds_mat_key]:-} ]] || continue
            _nds_mat_when=${_NDS_SCHEMA_ATTR[$_nds_mat_key|generate_when]:-}
            [[ -n "$_nds_mat_when" ]] || continue
            _nds_schema_condHolds "$_nds_mat_name" "$_nds_mat_when" || continue
            _nds_mat_dest="${ nds_session_dir secrets; }/${_nds_mat_key%_FILE}"
            "$_nds_mat_fn" "$_nds_mat_name" "$_nds_mat_key" "$_nds_mat_dest" || return 1
            nds_recipe_set "$_nds_mat_name" "$_nds_mat_key" "$_nds_mat_dest"
        done < <(nds_schema_groupFields "$_nds_mat_group")
    done < <(nds_schema_groups)
}
