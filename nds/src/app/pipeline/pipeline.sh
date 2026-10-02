#!/usr/bin/env bash
# ==================================================================================================
# NDS - Pipeline
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-09-26 | Modified: 2026-09-26
# Description:   Discover, cook, seal, cook, bundle. Unattended never opens a screen.
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

eventCreate recipe.schema
eventCreate recipe.done

_nds_pipeline_ask="${BASH_SOURCE[0]%/*}/../../wizard/ask.sh"
_nds_pipeline_access="${BASH_SOURCE[0]%/*}/../../wizard/git/closure.sh"
if [[ -f "$_nds_pipeline_ask" ]]; then
    # shellcheck source=../../wizard/ask.sh
    source "$_nds_pipeline_ask"
fi
if [[ -f "$_nds_pipeline_access" ]]; then
    # shellcheck source=../../wizard/git/closure.sh
    source "$_nds_pipeline_access"
fi

_nds_pipeline_hooks() {
    local _pipe_hook_name=$1
    _NDS_RELOAD_HOOKS=0
    if declare -f hook_access >/dev/null; then
        hook_access "$_pipe_hook_name" || return 1
    fi
    if declare -f hook_ask >/dev/null; then
        hook_ask "$_pipe_hook_name" || return 1
    fi
    if [[ ${_NDS_EXPORT_ONLY:-} == 1 ]]; then
        return 0
    fi
    if [[ ${_NDS_RELOAD_HOOKS:-} == 1 ]]; then
        _NDS_RELOAD_HOOKS=0
        _nds_pipeline_hooks "$_pipe_hook_name"
        return 0
    fi
    if declare -f nds_flake_note_disko >/dev/null; then
        nds_flake_note_disko "$_pipe_hook_name"
    fi
    if declare -f hook_material >/dev/null; then
        hook_material "$_pipe_hook_name" || return 1
    elif declare -f nds_recipe_materialize >/dev/null; then
        nds_recipe_materialize "$_pipe_hook_name"
    fi
    nds_recipe_validate "$_pipe_hook_name"
}

nds_catalog_load() {
    local -n _R=$1
    local _cat_dir _cat_name _cat_setup
    _cat_dir="${ nds_session_dir work; }/catalog"
    if [[ ! -d "${_cat_dir}/.git" ]]; then
        git_clone "${_R[GIT_KEYS_DIR]:-}" "${_R[CATALOG_URL]}" "$_cat_dir"
    fi
    nds_action_discover remote "${_cat_dir}/.nds/actions"
    _cat_name=${_R[CATALOG_ACTION]:-}
    _nds_action_store_has remote "$_cat_name" || {
        error "CATALOG_ACTION: not in the catalog"
        return 1
    }
    _cat_setup="${_cat_dir}/.nds/actions/${_cat_name}/setup.sh"
    unset -f hook_access hook_ask hook_material hook_cook hook_bundle
    unset -f action_groups action_preview action_defaults action_pins action_recipe action_plan action_access
    import_file "$_cat_setup"
    eventRun recipe.schema "$1"
    _NDS_RELOAD_HOOKS=1
}

_nds_pipeline_apply_lines() {
    local _pipe_name=$1 _pipe_lock=${2:-} _pipe_line _pipe_key _pipe_value
    while IFS= read -r _pipe_line; do
        [[ "$_pipe_line" == *=* ]] || continue
        _pipe_key=${_pipe_line%%=*}
        _pipe_value=${_pipe_line#*=}
        if [[ "$_pipe_lock" == lock ]]; then
            unset "_NDS_SCHEMA_ATTR[${_pipe_key}|locked]"
        fi
        nds_recipe_set "$_pipe_name" "$_pipe_key" "$_pipe_value" || return 1
        if [[ "$_pipe_lock" == lock ]]; then
            nds_schema_lock "$_pipe_key" || return 1
        fi
    done
    return 0
}

_nds_pipeline_take_file_action() {
    local _pipe_file _pipe_named
    if [[ -n ${NDS_RESTORE_FILE:-} ]]; then
        _pipe_file=${ nds_recipe_unpackBundle "$NDS_RESTORE_FILE"; }
        export NDS_RECIPE_FILE="$_pipe_file"
    fi
    if [[ -z ${NDS_IMPORT:-} && -z ${NDS_RESTORE_FILE:-} ]]; then
        return 0
    fi
    [[ -n ${NDS_RECIPE_FILE:-} ]] || { error "recipe: file not found"; return 1; }
    _pipe_named=${ nds_recipe_fileKey "$NDS_RECIPE_FILE" INSTALL_ACTION; }
    [[ -n "$_pipe_named" ]] || return 1
    if [[ -n ${NDS_ACTION:-} && "$NDS_ACTION" != "$_pipe_named" ]]; then
        error "--action ${NDS_ACTION} does not match INSTALL_ACTION=${_pipe_named}"
        return 1
    fi
    if ! _nds_action_store_has local "$_pipe_named"; then
        error "INSTALL_ACTION=${_pipe_named} is not valid (available: ${ _nds_action_joined local; })"
        return 1
    fi
    export NDS_ACTION="$_pipe_named"
}

nds_pipeline_recipe() {
    local _pipe_name=$1 _pipe_store=$2 _pipe_action=$3
    local -a _pipe_groups=()
    local _pipe_top=0
    _NDS_ANSWERED=()
    _NDS_MARK_ANSWERED=0
    eventRun recipe.schema "$_pipe_name" || return 1
    mapfile -t _pipe_groups < <(action_groups)
    if ((${#_pipe_groups[@]})); then
        nds_schema_enable "${_pipe_groups[@]}" || return 1
    fi
    nds_recipe_seed "$_pipe_name" || return 1
    if declare -f action_defaults >/dev/null; then
        _nds_pipeline_apply_lines "$_pipe_name" < <(action_defaults) || return 1
    fi
    [[ "$_pipe_store" == local && ${NDS_CURRENT_ACTION:-} == "$_pipe_action" ]] && _pipe_top=1
    _NDS_MARK_ANSWERED=1
    if [[ "$_pipe_top" -eq 1 && -n ${NDS_RECIPE_FILE:-} ]]; then
        nds_recipe_loadFile "$_pipe_name" "$NDS_RECIPE_FILE" || return 1
    fi
    nds_recipe_loadEnv "$_pipe_name" || return 1
    if [[ "$(nds_recipe_get "$_pipe_name" INSTALL_ACTION)" == remoteAction && "$_pipe_action" != remoteAction ]]; then
        :
    else
        unset "_NDS_SCHEMA_ATTR[INSTALL_ACTION|locked]"
        nds_recipe_set "$_pipe_name" INSTALL_ACTION "$_pipe_action" || return 1
        nds_schema_lock INSTALL_ACTION
    fi
    if declare -f action_pins >/dev/null; then
        _nds_pipeline_apply_lines "$_pipe_name" lock < <(action_pins) || return 1
    fi
    _NDS_MARK_ANSWERED=0
    if declare -f hook_access >/dev/null || declare -f hook_ask >/dev/null || declare -f hook_material >/dev/null; then
        _nds_pipeline_hooks "$_pipe_name"
    else
        if declare -f nds_access_run >/dev/null; then
            nds_access_run "$_pipe_name"
        fi
        if nds_mode_is_interactive; then
            nds_wizard_fill "$_pipe_name"
        fi
        if declare -f nds_flake_note_disko >/dev/null; then
            nds_flake_note_disko "$_pipe_name"
        fi
        if declare -f nds_recipe_materialize >/dev/null; then
            nds_recipe_materialize "$_pipe_name"
        fi
        if declare -f action_recipe >/dev/null; then
            action_recipe "$_pipe_name"
        fi
    fi
    eventRun recipe.done "$_pipe_name" || return 1
    if [[ ${_NDS_EXPORT_ONLY:-} == 1 ]]; then
        return 0
    fi
    nds_recipe_validate "$_pipe_name" || return 1
}

_nds_pipeline_unattended_finish() {
    local _pipe_sealed=$1 _pipe_zip=$2
    debug "Recipe: ${_pipe_sealed}"
    info "Bundle: ${_pipe_zip}"
    if [[ ${NDS_REBOOT:-} == true ]]; then
        info "Rebooting"
        reboot
    else
        info "Reboot the machine to start the installed system."
    fi
}

nds_pipeline_run() {
    local _pipe_src _pipe_fleet _pipe_sealed _pipe_zip
    nds_skip_startup || return 1
    _pipe_src=${ scriptInfo_get_dir; }
    nds_action_discover local "${_pipe_src}/actions" || return 1
    _nds_action_hide_debug
    if [[ -n ${NDS_FLEET_ACTIONS_DIR:-} ]]; then
        _pipe_fleet=$NDS_FLEET_ACTIONS_DIR
    else
        _pipe_fleet="${_pipe_src%/*/*}/fleet/nds-actions"
    fi
    if [[ -d "$_pipe_fleet" ]]; then
        nds_action_discover local "$_pipe_fleet" || return 1
    fi
    if _nds_action_store_empty local; then
        error "No valid actions"
        return 1
    fi
    _nds_pipeline_take_file_action || return 1
    nds_action_select || return 1
    info "Action: ${NDS_CURRENT_ACTION}"
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local "$NDS_CURRENT_ACTION" || return 1
    if [[ ${_NDS_EXPORT_ONLY:-} == 1 ]]; then
        _pipe_sealed=$(nds_recipe_saveHome _NDS_RECIPE) || return 1
        if declare -f chrome_end >/dev/null; then
            chrome_end || true
        fi
        printf 'Recipe saved: %s\n' "$_pipe_sealed" >&2
        printf 'Nothing was installed. Import it with --import %s\n' "$_pipe_sealed" >&2
        info "Recipe: ${_pipe_sealed}"
        return 0
    fi
    if ! declare -f hook_material >/dev/null; then
        nds_recipe_materialize _NDS_RECIPE || return 1
    fi
    if declare -f action_plan >/dev/null; then
        action_plan _NDS_RECIPE || return 1
    fi
    _pipe_sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$_pipe_sealed" || return 1
    debug "Sealed recipe ${_pipe_sealed}"
    if declare -f hook_cook >/dev/null; then
        hook_cook _NDS_RECIPE || return 1
    else
        nds_cook "$_pipe_sealed" || return 1
    fi
    if declare -f hook_bundle >/dev/null; then
        hook_bundle _NDS_RECIPE || return 1
    fi
    # Do not capture stdout. info/debug write there, and this shell would
    # print those lines a second time inside "Bundle:".
    _NDS_BUNDLE_OUT=""
    nds_bundle "$_pipe_sealed" || return 1
    _pipe_zip=$_NDS_BUNDLE_OUT
    [[ -n "$_pipe_zip" ]] || return 1
    if nds_mode_is_unattended; then
        _nds_pipeline_unattended_finish "$_pipe_sealed" "$_pipe_zip"
        return 0
    fi
    nds_finish "$_pipe_sealed" "$_pipe_zip"
}
