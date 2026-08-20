#!/usr/bin/env bash
# ==================================================================================================
# NDS - Install UI: preflight warning continues
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-06 | Modified: 2026-08-06
# ==================================================================================================

declare -f nds_skip_register &>/dev/null && nds_skip_register NDS_PREFLIGHT_WARN_SKIP

# Description: Ask to continue after a preflight warning (honors skip).
# Arguments:
# - prompt: <String> Proceed question
nds_install_ui_preflight_continue() {
    local prompt="${1:-Continue anyway?}"
    if nds_skip_menu NDS_PREFLIGHT_WARN_SKIP; then
        return 0
    fi
    nds_ask_user_to_proceed "$prompt"
}
