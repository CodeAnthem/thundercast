#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe validate
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Type, required, and group checks. Returns the problem count.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_recipe_validate() {
    local _nds_val_name=$1
    local -n _nds_val_aa=$1
    local _nds_val_n=0 _nds_val_group _nds_val_key _nds_val_value _nds_val_type _nds_val_fn _nds_val_rc
    while IFS= read -r _nds_val_group; do
        [[ -n "$_nds_val_group" ]] || continue
        nds_schema_groupIsActive "$_nds_val_name" "$_nds_val_group" || continue
        while IFS= read -r _nds_val_key; do
            [[ -n "$_nds_val_key" ]] || continue
            nds_schema_isActive "$_nds_val_name" "$_nds_val_key" || continue
            _nds_val_value=${_nds_val_aa[$_nds_val_key]:-}
            if [[ ${_NDS_SCHEMA_ATTR[$_nds_val_key|required]:-} == 1 && -z "$_nds_val_value" ]]; then
                error "${_nds_val_key}: required"
                _nds_val_n=$((_nds_val_n + 1))
                continue
            fi
            [[ -n "$_nds_val_value" ]] || continue
            _nds_val_type=${_NDS_SCHEMA_FIELD_TYPE[$_nds_val_key]}
            if ! _nds_type_ok "$_nds_val_type" "$_nds_val_value" "$_nds_val_key"; then
                error "${_nds_val_key}: invalid ${_nds_val_type}"
                _nds_val_n=$((_nds_val_n + 1))
                continue
            fi
            _nds_val_fn=${_NDS_SCHEMA_ATTR[$_nds_val_key|validate]:-}
            if [[ -n "$_nds_val_fn" ]] && ! "$_nds_val_fn" "$_nds_val_value"; then
                error "${_nds_val_key}: rejected"
                _nds_val_n=$((_nds_val_n + 1))
            fi
        done < <(nds_schema_groupFields "$_nds_val_group")
    done < <(nds_schema_groups)
    while IFS= read -r _nds_val_group; do
        [[ -n "$_nds_val_group" ]] || continue
        nds_schema_groupIsActive "$_nds_val_name" "$_nds_val_group" || continue
        _nds_val_fn=${_NDS_SCHEMA_GROUP_CHECK[$_nds_val_group]:-}
        [[ -n "$_nds_val_fn" ]] || continue
        _nds_val_rc=0
        "$_nds_val_fn" "$_nds_val_name" || _nds_val_rc=$?
        _nds_val_n=$((_nds_val_n + _nds_val_rc))
    done < <(nds_schema_groups)
    return "$_nds_val_n"
}
