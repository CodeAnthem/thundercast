#!/usr/bin/env bash
# ==================================================================================================
# NDS - Example remote preset (copy to your flake as .nds/presets/custom.sh)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-07-06 | Modified: 2026-07-06
# Description:   Reference preset loaded by nds_preset_inject_from_flake
# ==================================================================================================

custom_defaults() {
    nds_cfg_set CUSTOM_NOTES ""
}

custom_configure() {
    nds_cfg_section_title "Custom (from flake)"
    nds_cfg_ask_string CUSTOM_NOTES "Install notes (optional)" "" false
}

custom_summary() {
    local notes
    notes="$(nds_cfg_get CUSTOM_NOTES)"
    [[ -n "$notes" ]] && nds_cfg_summary_row "Notes" "$notes"
}

custom_validate() {
    return 0
}

if declare -f nds_preset_register_hooks &>/dev/null; then
    nds_preset_register_hooks \
        defaults=custom_defaults \
        configure=custom_configure \
        validate=custom_validate \
        summary=custom_summary
fi

NDS_PRESET_PRIORITY=25
NDS_PRESET_DISPLAY="Custom (flake)"
