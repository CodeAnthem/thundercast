#!/usr/bin/env bash
# ==================================================================================================
# NDS - Action store (discovery and registry)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-29 | Modified: 2026-09-01
# Description:   Discover, validate, and store available actions
# ==================================================================================================

declare -ga NDS_ACTION_NAMES=()
declare -gA NDS_ACTION_DATA=()
declare -g NDS_ACTIONS_DIR=""
declare -g NDS_CURRENT_ACTION=""

# Description: True when setup.sh defines the given function (regex, e.g. action_setup).
_nds_app_actionManager_hasFn() {
    local action_path="$1" fn="$2"
    local setup="${action_path}/setup.sh"
    [[ -f "$setup" ]] || return 1
    grep -qE "^${fn}\(\)" "$setup"
}

_nds_app_actionManager_validate() {
    local action_name="$1"
    local action_path="$2"
    local setup_script="${action_path}/setup.sh"

    [[ -f "$setup_script" ]] || { debug "Action '$action_name': Missing setup.sh"; return 1; }
    _nds_app_actionManager_hasFn "$action_path" 'action_(config|presets)' || {
        debug "Action '$action_name': Missing action_presets() or action_config()"; return 1; }
    _nds_app_actionManager_hasFn "$action_path" 'action_preview' || {
        debug "Action '$action_name': Missing action_preview()"; return 1; }
    _nds_app_actionManager_hasFn "$action_path" 'action_setup' || {
        debug "Action '$action_name': Missing action_setup()"; return 1; }

    local description
    description=$(head -n 20 "$setup_script" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//' 2>/dev/null)
    [[ -n "$description" ]] || { debug "Action '$action_name': Missing description"; return 1; }
    return 0
}

# Description: ThunderCast repo root (parent of nds/). SCRIPT_DIR is nds/src.
_nds_app_repo_root() {
    cd "${SCRIPT_DIR}/../.." && pwd
}

# Description: Default fleet NDS action pack (toolkit / addFleetHost). Override with NDS_FLEET_ACTIONS_DIR.
_nds_app_fleet_actions_dir() {
    if [[ -n "${NDS_FLEET_ACTIONS_DIR:-}" ]]; then
        printf '%s\n' "$NDS_FLEET_ACTIONS_DIR"
        return 0
    fi
    printf '%s/fleet/nds-actions\n' "${ _nds_app_repo_root; }"
}

# Description: Register one action directory if valid (skips duplicates).
_nds_app_actionManager_registerDir() {
    local action_dir="$1"
    local action_name description

    [[ -d "$action_dir" ]] || return 0
    action_name=$(basename "$action_dir")
    case "$action_name" in
        test|uiSmoke)
            [[ "${NDS_TEST:-false}" == "true" ]] || return 0
            ;;
    esac
    [[ -z "${NDS_ACTION_DATA[${action_name}_path]:-}" ]] || {
        debug "Action '$action_name': already registered — skip"
        return 0
    }
    _nds_app_actionManager_validate "$action_name" "$action_dir" || {
        warn "Skipping invalid action: $action_name"
        return 0
    }
    description=$(head -n 20 "${action_dir}setup.sh" | grep -m1 "^# Description:" | sed 's/^# Description:[[:space:]]*//')
    NDS_ACTION_NAMES+=("$action_name")
    NDS_ACTION_DATA["${action_name}_path"]="$action_dir"
    NDS_ACTION_DATA["${action_name}_description"]="$description"
}

# Description: Scan actions directories, validate each action, populate NDS_ACTION_NAMES and NDS_ACTION_DATA.
# Always merges fleet/nds-actions when present (ThunderCast cluster birth wizards).
# Arguments:
# - actions_dir: <String> Path to the core NDS actions directory
# Returns:
# - <Bool> 0 when at least one valid action is found
nds_app_actionManager_logic_discover() {
    local actions_dir="${1:?actions dir}"
    local action_dir fleet_dir

    NDS_ACTIONS_DIR="$actions_dir"
    NDS_ACTION_NAMES=()
    NDS_ACTION_DATA=()

    [[ -d "$NDS_ACTIONS_DIR" ]] || { error "Actions directory not found: $NDS_ACTIONS_DIR"; return 1; }

    for action_dir in "$NDS_ACTIONS_DIR"/*/; do
        _nds_app_actionManager_registerDir "$action_dir"
    done

    fleet_dir="${ _nds_app_fleet_actions_dir; }"
    if [[ -d "$fleet_dir" ]]; then
        for action_dir in "$fleet_dir"/*/; do
            _nds_app_actionManager_registerDir "$action_dir"
        done
    fi

    [[ ${#NDS_ACTION_NAMES[@]} -gt 0 ]] || { error "No valid actions in $NDS_ACTIONS_DIR"; return 1; }
    debug "Discovered ${#NDS_ACTION_NAMES[@]} actions"
    return 0
}
