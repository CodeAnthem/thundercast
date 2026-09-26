#!/usr/bin/env bash
# ==================================================================================================
# NDS - Catalog action asker
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

nds_ask_catalogAction() {
    local _cat_name=$1 _cat_key=$2 _cat_url _cat_dir _cat_one _cat_rc=0
    _cat_url=$(nds_recipe_get "$_cat_name" CATALOG_URL)
    _cat_dir="${ nds_session_dir work; }/catalog"
    git_clone "$(nds_recipe_get "$_cat_name" GIT_KEYS_DIR)" "$_cat_url" "$_cat_dir" || return 1
    nds_action_discover remote "${_cat_dir}/.nds/actions" || return 1
    _nds_wiz_opts=()
    while IFS= read -r _cat_one; do
        [[ -n "$_cat_one" ]] && _nds_wiz_opts+=("${_cat_one}|${_cat_one}")
    done < <(_nds_action_store_names remote)
    if ((${#_nds_wiz_opts[@]} == 0)); then
        error "CATALOG_ACTION: no actions"
        return 1
    fi
    _nds_ask_run "$_cat_name" "$_cat_key" --type select --options _nds_wiz_opts || _cat_rc=$?
    return "$_cat_rc"
}
