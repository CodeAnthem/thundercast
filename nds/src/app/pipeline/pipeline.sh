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

_nds_pipeline_loadRecipeAction() {
    local _pipe_name=$1 _pipe_action _pipe_setup
    _pipe_action=${ nds_recipe_get "$_pipe_name" INSTALL_ACTION; }
    [[ -n "$_pipe_action" && "$_pipe_action" != apply ]] || return 0
    if _nds_action_store_has local "$_pipe_action" || _nds_action_store_has remote "$_pipe_action"; then
        if _nds_action_store_has local "$_pipe_action"; then
            _pipe_setup=${ _nds_action_store_path local "$_pipe_action"; }
        else
            _pipe_setup=${ _nds_action_store_path remote "$_pipe_action"; }
        fi
        import_file "$_pipe_setup" || return 1
        unset -f action_recipe
        return 0
    fi
    error "${_pipe_action}: unknown action"
    return 1
}

nds_pipeline_recipe() {
    local _pipe_name=$1 _pipe_store=$2 _pipe_action=$3
    local -a _pipe_groups=()
    local _pipe_top=0
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
    if [[ "$_pipe_top" -eq 1 && -n ${NDS_RECIPE_FILE:-} ]]; then
        nds_recipe_loadFile "$_pipe_name" "$NDS_RECIPE_FILE" || return 1
        if [[ "$_pipe_action" == apply ]]; then
            _nds_pipeline_loadRecipeAction "$_pipe_name" || return 1
        fi
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
    if nds_mode_is_interactive; then
        nds_wizard_fill "$_pipe_name" || return 1
    else
        nds_recipe_validate "$_pipe_name" || return 1
    fi
    if declare -f action_recipe >/dev/null; then
        action_recipe "$_pipe_name" || return 1
    fi
    eventRun recipe.done "$_pipe_name" || return 1
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
    nds_action_select || return 1
    info "Action: ${NDS_CURRENT_ACTION}"
    declare -gA _NDS_RECIPE=()
    nds_pipeline_recipe _NDS_RECIPE local "$NDS_CURRENT_ACTION" || return 1
    nds_recipe_materialize _NDS_RECIPE || return 1
    _pipe_sealed="${ nds_session_dir recipe; }/sealed.recipe"
    nds_recipe_seal _NDS_RECIPE "$_pipe_sealed" || return 1
    debug "Sealed recipe ${_pipe_sealed}"
    if ! nds_skip install.confirm; then
        nds_confirm "$_pipe_sealed" || return 1
    fi
    nds_cook "$_pipe_sealed" || return 1
    _pipe_zip=${ nds_bundle "$_pipe_sealed"; } || return 1
    if nds_mode_is_unattended; then
        _nds_pipeline_unattended_finish "$_pipe_sealed" "$_pipe_zip"
        return 0
    fi
    nds_finish "$_pipe_sealed" "$_pipe_zip"
}
