#!/usr/bin/env bash
# ==================================================================================================
# NDS - Remote catalog action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-09-26
# Description:   Clone a catalog and cook the named action after its preview
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    printf '%s\n' install catalog
}

action_preview() {
    ui_h "Run an action from a catalog"
    ui_b "Clone the catalog, accept that action, then cook its recipe."
}

action_pins() {
    printf '%s\n' INSTALL_KIND=flake
}

action_cook() {
    local -n _R=$1
    local _cat_dir _cat_name _cat_setup
    _cat_dir="${ nds_session_dir work; }/catalog"
    if nds_mode_is_unattended; then
        git_clone "${_R[GIT_KEYS_DIR]:-}" "${_R[CATALOG_URL]}" "$_cat_dir" || return 1
    fi
    nds_action_discover remote "${_cat_dir}/.nds/actions" || return 1
    _cat_name=${_R[CATALOG_ACTION]:-}
    _nds_action_store_has remote "$_cat_name" || {
        error "CATALOG_ACTION: not in the catalog"
        return 1
    }
    _cat_setup="${_cat_dir}/.nds/actions/${_cat_name}/setup.sh"
    _nds_action_clear_sourced
    import_file "$_cat_setup" || return 1
    if ! nds_skip action.preview; then
        action_preview || return 1
    fi
    nds_pipeline_cook "$1" remote "$_cat_name" || return 1
}
