#!/usr/bin/env bash
# ==================================================================================================
# NDS - Preset registry (enable / display / priority)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-01 | Modified: 2026-08-16
# Description:   PRESET_REGISTRY helpers used by the settings menu
# ==================================================================================================

# Description: Register a preset as enabled with menu priority and display title.
nds_preset_register() {
    local name="$1"
    local priority="$2"
    local display="$3"
    PRESET_REGISTRY["$name"]="enabled"
    PRESET_META["${name}__priority"]="$priority"
    PRESET_META["${name}__display"]="$display"
}

# Description: Register preset metadata without loading hooks (catalog entry, disabled).
nds_preset_register_catalog() {
    local name="$1"
    local priority="$2"
    local display="$3"
    PRESET_REGISTRY["$name"]="disabled"
    PRESET_META["${name}__priority"]="$priority"
    PRESET_META["${name}__display"]="$display"
}

# Description: Enable a registered preset.
nds_cfg_preset_enable() {
    PRESET_REGISTRY["$1"]="enabled"
}

# Description: Disable a registered preset (no-op if unknown).
nds_cfg_preset_disable() {
    [[ -n "${PRESET_REGISTRY[$1]:-}" ]] || return 0
    PRESET_REGISTRY["$1"]="disabled"
}

# Description: Set a preset's menu sort priority.
nds_cfg_preset_set_priority() {
    PRESET_META["${1}__priority"]="$2"
}

# Description: Set a preset's menu display title.
nds_cfg_preset_set_display() {
    PRESET_META["${1}__display"]="$2"
}

# Description: Read a preset's menu sort priority (default 50).
nds_cfg_preset_get_priority() {
    echo "${PRESET_META[${1}__priority]:-50}"
}

# Description: Read a preset's menu display title.
nds_cfg_preset_get_display() {
    local preset="$1"
    local display="${PRESET_META[${preset}__display]:-}"
    if [[ -z "$display" ]]; then
        display="$(echo "${preset^}" | tr '_' ' ')"
    fi
    echo "$display"
}

_nds_cfg_sort_presets() {
    local presets=("$@")
    [[ ${#presets[@]} -eq 0 ]] && return 0
    local sorted=() preset priority
    for preset in "${presets[@]}"; do
        priority=$(nds_cfg_preset_get_priority "$preset")
        sorted+=("${priority}:${preset}")
    done
    printf '%s\n' "${sorted[@]}" | sort -t: -k1,1n -k2,2 | cut -d: -f2
}

# Description: List enabled presets in menu order (stdout).
nds_cfg_preset_get_all_enabled() {
    local presets=() preset
    for preset in "${!PRESET_REGISTRY[@]}"; do
        [[ "${PRESET_REGISTRY[$preset]}" == "enabled" ]] && presets+=("$preset")
    done
    _nds_cfg_sort_presets "${presets[@]}"
}
