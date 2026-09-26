#!/usr/bin/env bash
# ==================================================================================================
# NDS - Apply a recipe
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date:          Created: 2026-08-20 | Modified: 2026-09-26
# Description:   Review every group from a recipe file, then birth the machine
# ==================================================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "This script must be sourced, not run directly." >&2; exit 1; fi

action_groups() {
    nds_schema_allGroups
}

action_preview() {
    ui_h "Apply a recipe"
    ui_b "Load a recipe file or zip, review the active fields, then birth the machine."
}
