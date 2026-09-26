#!/usr/bin/env bash
# ==================================================================================================
# NDS - Recipe seed
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Fill empty enabled fields from --default and --detect.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_recipe_seed() {
    local _nds_seed_name=$1 _nds_seed_group _nds_seed_key _nds_seed_detect _nds_seed_default _nds_seed_line
    while IFS= read -r _nds_seed_group; do
        [[ -n "$_nds_seed_group" ]] || continue
        while IFS= read -r _nds_seed_key; do
            [[ -n "$_nds_seed_key" ]] || continue
            nds_recipe_has "$_nds_seed_name" "$_nds_seed_key" && continue
            _nds_seed_detect=${_NDS_SCHEMA_ATTR[$_nds_seed_key|detect]:-}
            _nds_seed_default=${_NDS_SCHEMA_ATTR[$_nds_seed_key|default]:-}
            [[ -n "$_nds_seed_detect" || -n "$_nds_seed_default" ]] || continue
            if [[ -n "$_nds_seed_detect" ]]; then
                _nds_seed_line=${ "$_nds_seed_detect"; } || return 1
                if [[ -n "$_nds_seed_line" ]]; then
                    nds_recipe_set "$_nds_seed_name" "$_nds_seed_key" "$_nds_seed_line"
                    continue
                fi
            fi
            if [[ -n "$_nds_seed_default" ]]; then
                nds_recipe_set "$_nds_seed_name" "$_nds_seed_key" "$_nds_seed_default"
            fi
        done < <(nds_schema_groupFields "$_nds_seed_group")
    done < <(nds_schema_groups)
}
