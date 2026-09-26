#!/usr/bin/env bash
# ==================================================================================================
# NDS - Scaffold role asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_ask_role() {
    local _role_name=$1 _role_key=$2 _role_root _role_host _role_dir _role_recipe _role_rc=0
    _role_root=$(_nds_ask_flake_root "$_role_name")
    _role_host=$(nds_recipe_get "$_role_name" FLAKE_HOST)
    _role_recipe="${_role_root}/.nds/hosts/${_role_host}.recipe"
    _nds_wiz_opts=()
    if [[ -d "${_role_root}/.roles" ]]; then
        for _role_dir in "${_role_root}/.roles"/*; do
            [[ -d "$_role_dir" ]] || continue
            _nds_wiz_opts+=("$(basename "$_role_dir")|$(basename "$_role_dir")")
        done
    fi
    if [[ -f "$_role_recipe" ]]; then
        _nds_wiz_opts+=("restore|Restore ${_role_host}")
    fi
    if ((${#_nds_wiz_opts[@]} == 0)); then
        _nds_ask_text "$_role_name" "$_role_key"
        return
    fi
    _nds_ask_run "$_role_name" "$_role_key" --type select --options _nds_wiz_opts || _role_rc=$?
    [[ "$_role_rc" -eq 0 ]] || return "$_role_rc"
    if [[ "$UI_PROMPT_RESULT" == restore ]]; then
        nds_recipe_loadFile "$_role_name" "$_role_recipe" || return 1
    fi
}
