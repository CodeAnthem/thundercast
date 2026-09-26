#!/usr/bin/env bash
# ==================================================================================================
# NDS - UI smoke action
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-07 | Modified: 2026-09-26
# Description:   Interactive screen walk, hidden unless NDS_TEST is set
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    :
}

action_preview() {
    ui_h "UI smoke"
    ui_b "Walk the interactive screens. Nothing is installed."
}
