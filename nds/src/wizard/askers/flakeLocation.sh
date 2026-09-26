#!/usr/bin/env bash
# ==================================================================================================
# NDS - Flake location asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_ask_flakeLocation() {
    local _loc_name=$1 _loc_key=$2 _loc_rc=0 _loc_value
    _nds_ask_text "$_loc_name" "$_loc_key" || _loc_rc=$?
    [[ "$_loc_rc" -eq 0 ]] || return "$_loc_rc"
    _loc_value=$(nds_recipe_get "$_loc_name" "$_loc_key")
    case "$_loc_value" in
        /*|~*|.*)
            nds_recipe_set "$_loc_name" FLAKE_SOURCE local
            nds_recipe_set "$_loc_name" FLAKE_LOCAL_PATH "$_loc_value"
            ;;
        *)
            nds_recipe_set "$_loc_name" FLAKE_SOURCE remote
            nds_recipe_set "$_loc_name" FLAKE_REPO_URL "$_loc_value"
            ;;
    esac
}
