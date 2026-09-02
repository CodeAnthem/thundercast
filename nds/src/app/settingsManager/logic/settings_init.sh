#!/usr/bin/env bash
# ==================================================================================================
# NDS - Settings manager init (catalog + default bundle)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-27 | Modified: 2026-08-15
# Description:   Catalog builtins; nds_cfg_init seeds the classic preset bundle
# ==================================================================================================

declare -ga NDS_DEFAULT_PRESET_BUNDLE=(
    disk encryption region network boot access quick platform
)

# Description: Catalog builtin presets without enabling or seeding.
nds_settings_catalog_init() {
    debug "Cataloging builtin presets..."
    nds_preset_catalog_builtin "$SCRIPT_DIR" || {
        fatal "Failed to catalog builtin presets"
        return 1
    }
    debug "Preset catalog ready (${#PRESET_REGISTRY[@]} cataloged)"
    return 0
}

# Description: Catalog + enable default classic bundle + seed (tests / non-action use).
nds_cfg_init() {
    debug "Initializing settings manager..."

    nds_settings_catalog_init || return 1

    nds_preset_enable_bundle "$SCRIPT_DIR" "${NDS_DEFAULT_PRESET_BUNDLE[@]}" || {
        fatal "Failed to enable default preset bundle"
        return 1
    }

    nds_cfg_seed_defaults

    debug "Settings initialized (${#PRESET_REGISTRY[@]} cataloged, hooks loaded on demand)"
    return 0
}
