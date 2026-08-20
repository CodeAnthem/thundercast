#!/usr/bin/env bash
# ==================================================================================================
# NDS - Configuration store (get/set + snapshot + action reset)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-16
# Description:   Flat CONFIG_DATA / preset registry globals
# ==================================================================================================

declare -gA CONFIG_DATA=()
declare -gA CONFIG_DEFAULTS=()
declare -gA PRESET_REGISTRY=()
declare -gA PRESET_META=()
# Hook function names: PRESET_HOOKS["${preset}__validate"]="disk_validate" …
declare -gA PRESET_HOOKS=()

# When set, nds_cfg_get/set target this nameref name (feature AA) instead of CONFIG_DATA.
declare -g NDS_CFG_AA_NAME="${NDS_CFG_AA_NAME:-}"

# Description: Read a config key (bound feature AA, else CONFIG_DATA).
nds_cfg_get() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        # shellcheck disable=SC2178
        local -n _nds_cfg_aa_live="${NDS_CFG_AA_NAME}"
        echo "${_nds_cfg_aa_live[$1]:-${2:-}}"
        return 0
    fi
    echo "${CONFIG_DATA[$1]:-${2:-}}"
}

# Description: Write a config key (bound feature AA, else CONFIG_DATA).
nds_cfg_set() {
    if [[ -n "${NDS_CFG_AA_NAME:-}" ]]; then
        # shellcheck disable=SC2178
        local -n _nds_cfg_aa_live="${NDS_CFG_AA_NAME}"
        _nds_cfg_aa_live["$1"]="$2"
        return 0
    fi
    CONFIG_DATA["$1"]="$2"
}

# Description: True when a config key equals the given value.
nds_cfg_is() {
    [[ "$(nds_cfg_get "$1")" == "$2" ]]
}

# Description: True when a config key is the string true.
nds_cfg_true() {
    nds_cfg_is "$1" true
}

# Description: Copy current CONFIG_DATA into CONFIG_DEFAULTS (after seed, before edits).
nds_cfg_snapshot_defaults() {
    CONFIG_DEFAULTS=()
    local k
    for k in "${!CONFIG_DATA[@]}"; do
        CONFIG_DEFAULTS["$k"]="${CONFIG_DATA[$k]}"
    done
}

# Description: Disable every builtin preset (used when an action has no action_presets hook).
nds_cfg_reset_for_action() {
    local bootstrap_dir="${1:?bootstrap dir}"
    local preset preset_dir preset_file
    preset_dir="$(nds_preset_dir "$bootstrap_dir")"
    for preset_file in "${preset_dir}/"*.sh; do
        [[ -f "$preset_file" ]] || continue
        preset=$(basename "$preset_file" .sh)
        nds_cfg_preset_enable "$preset"
        unset "PRESET_META[${preset}__display]"
    done
    for preset in installFlake remoteAction; do
        nds_cfg_preset_disable "$preset"
        unset "PRESET_META[${preset}__display]"
        unset "PRESET_META[${preset}__priority]"
    done
}
