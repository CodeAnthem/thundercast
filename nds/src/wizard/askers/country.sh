#!/usr/bin/env bash
# ==================================================================================================
# NDS - Country asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

_nds_country_if_seed() {
    local _co_name=$1 _co_key=$2 _co_next=$3 _co_cur _co_def
    [[ -n "$_co_next" ]] || return 0
    _co_cur=$(nds_recipe_get "$_co_name" "$_co_key")
    _co_def=$(nds_schema_attr "$_co_key" default)
    if [[ -z "$_co_cur" || "$_co_cur" == "$_co_def" ]]; then
        nds_recipe_set "$_co_name" "$_co_key" "$_co_next"
    fi
}

nds_ask_country() {
    local _co_name=$1 _co_key=$2 _co_rc=0 _co_country _co_line _co_tz _co_loc _co_kb _co_var
    _nds_ask_text "$_co_name" "$_co_key" || _co_rc=$?
    [[ "$_co_rc" -eq 0 ]] || return "$_co_rc"
    _co_country=$(nds_recipe_get "$_co_name" "$_co_key")
    _co_line=$(nds_country_defaults "$_co_country") || return 0
    IFS='|' read -r _co_tz _co_loc _co_kb _co_var <<< "$_co_line"
    _nds_country_if_seed "$_co_name" REGION_TIMEZONE "$_co_tz"
    _nds_country_if_seed "$_co_name" REGION_LOCALE_MAIN "$_co_loc"
    _nds_country_if_seed "$_co_name" REGION_KEYBOARD_LAYOUT "$_co_kb"
    _nds_country_if_seed "$_co_name" REGION_KEYBOARD_VARIANT "$_co_var"
}
