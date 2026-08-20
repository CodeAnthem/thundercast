#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action store (discovery and registry)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-08-15
# Description:   Discover, validate, and store available actions
# ==================================================================================================

declare -ga NDS_ACTION_NAMES=()
declare -gA NDS_ACTION_DATA=()
declare -g NDS_ACTIONS_DIR=""
declare -g NDS_CURRENT_ACTION=""

# Description: True when setup.sh defines the given function (regex, e.g. action_setup).
_nds_app_actionHandler_hasFn() {
    local action_path="$1" fn="$2"
    local setup="${action_path}/setup.sh"
    [[ -f "$setup" ]] || return 1
    grep -qE "^${fn}\(\)" "$setup"
}

_nds_app_actionHandler_validate() {
    local action_name="$1"
    local action_path="$2"
    local setup_script="${action_path}/setup.sh"

    [[ -f "$setup_script" ]] || { debug "Action '$action_name': Missing setup.sh"; return 1; }
    _nds_app_actionHandler_hasFn "$action_path" 'action_(config|presets)' || {
        debug "Action '$action_name': Missing action_presets() or action_config()"; return 1; }
    _nds_app_actionHandler_hasFn "$action_path" 'action_preview' || {
        debug "Action '$action_name': Missing action_preview()"; return 1; }
    _nds_app_actionHandler_hasFn "$action_path" 'action_setup' || {
        debug "Action '$action_name': Missing action_setup()"; return 1; }

    local description
    description=$(head -n 20 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null)
    [[ -n "$description" ]] || { debug "Action '$action_name': Missing description"; return 1; }
    return 0
}

# Description: Scan the actions directory, validate each action, populate NDS_ACTION_NAMES and NDS_ACTION_DATA.
# Arguments:
# - actions_dir: <String> Path to the actions directory
# Returns:
# - <Bool> 0 when at least one valid action is found
nds_app_actionHandler_logic_discover() {
    local actions_dir="${1:?actions dir}"
    NDS_ACTIONS_DIR="$actions_dir"
    NDS_ACTION_NAMES=()

    [[ -d "$NDS_ACTIONS_DIR" ]] || { error "Actions directory not found: $NDS_ACTIONS_DIR"; return 1; }

    local action_dir action_name description
    for action_dir in "$NDS_ACTIONS_DIR"/*/; do
        [[ -d "$action_dir" ]] || continue
        action_name=$(basename "$action_dir")
        # Debug-only actions (read-only selftest / interactive UI smoke)
        case "$action_name" in
            test|uiSmoke)
                [[ "${NDS_TEST:-false}" == "true" ]] || continue
                ;;
        esac
        _nds_app_actionHandler_validate "$action_name" "$action_dir" || { warn "Skipping invalid action: $action_name"; continue; }
        description=$(head -n 20 "${action_dir}setup.sh" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//')
        NDS_ACTION_NAMES+=("$action_name")
        NDS_ACTION_DATA["${action_name}_path"]="$action_dir"
        NDS_ACTION_DATA["${action_name}_description"]="$description"
    done

    [[ ${#NDS_ACTION_NAMES[@]} -gt 0 ]] || { error "No valid actions in $NDS_ACTIONS_DIR"; return 1; }
    debug "Discovered ${#NDS_ACTION_NAMES[@]} actions"
    return 0
}
