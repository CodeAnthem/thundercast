#!/usr/bin/env bash
# ==================================================================================================
# Thundercast - Catalog shim (addRole is a built-in NDS action)
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-18 | Modified: 2026-08-20
# Description:   Not a remote action — use NDS_ACTION=addRole
# ==================================================================================================

action_presets() {
    printf '%s\n' remoteAction
}

action_config() { :; }

action_preview() {
    nds_ui_h "addRole is built-in"
    nds_ui_b "Use NDS_ACTION=addRole (or the addRole menu entry). This catalog file is a stub."
}

remote_action_run() {
    error "addRole is a built-in NDS action — not a remote catalog script (NDS_ACTION=addRole)"
    return 1
}
