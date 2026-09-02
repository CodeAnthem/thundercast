#!/usr/bin/env bash
# ==================================================================================================
# NDS - Test action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-06-28 | Modified: 2026-08-14
# Description:   Run full CI selftest suite — no system changes
# ==================================================================================================

# ----------------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------------

action_config() {
    nds_cfg_preset_disable disk
    nds_cfg_preset_disable quick
    nds_cfg_preset_disable region
    nds_cfg_preset_disable network
    nds_cfg_preset_disable boot
    nds_cfg_preset_disable installFlake
}

# ----------------------------------------------------------------------------------
# Preview
# ----------------------------------------------------------------------------------

action_preview() {
    nds_ui_h "NDS self-tests (read-only)"
    nds_ui_b ""
    nds_ui_b "You will configure:"
    nds_ui_i "nothing — no install settings required"
    nds_ui_b ""
    nds_ui_b "NDS will:"
    nds_app_actionManager_ui_listItems "run the full CI selftest suite (structure, validators, git, tools, install helpers, …)"
    nds_ui_b ""
    nds_ui_b "For interactive prompt walking use action uiSmoke (also needs NDS_TEST=true)."
    nds_ui_b ""
}

# ----------------------------------------------------------------------------------
# Setup
# ----------------------------------------------------------------------------------

action_setup() {
    console "Running full NDS self-tests (same as CI / bash nds/dev/selftest.sh)."
    local root
    root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    bash "${root}/nds/dev/selftest.sh" || exit 1
}
